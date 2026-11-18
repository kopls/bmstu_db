import argparse
import json
import os
import time
from pathlib import Path

import requests
import urllib3

ROOT = Path(__file__).resolve().parent


class NiFi:
    def __init__(self, url):
        self.url = url.rstrip('/') + '/nifi-api'
        self.session = requests.Session()
        # Локальный NiFi использует самоподписанный сертификат.
        self.session.verify = False
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        response = self.session.post(self.url + '/access/token', data={
            'username': os.getenv('NIFI_USER', 'artyom'),
            'password': os.getenv('NIFI_PASSWORD', 'warehouse12345')
        }, timeout=30)
        response.raise_for_status()
        self.session.headers['Authorization'] = 'Bearer ' + response.text

    def call(self, method, path, body=None):
        response = self.session.request(method, self.url + path, json=body, timeout=30)
        if not response.ok:
            raise RuntimeError(f'{method} {path}: {response.status_code} {response.text[:1500]}')
        return response.json() if response.content else {}

    def component_type(self, name, service=False):
        endpoint = '/flow/controller-service-types' if service else '/flow/processor-types'
        key = 'controllerServiceTypes' if service else 'processorTypes'
        for item in self.call('GET', endpoint)[key]:
            if item['type'].rsplit('.', 1)[-1] == name:
                return {'type': item['type'], 'bundle': item['bundle']}
        raise RuntimeError('Компонент не найден: ' + name)

    def properties(self, descriptors, values):
        # Названия на схеме такие же, как в интерфейсе NiFi.
        result = {}
        for name, value in values.items():
            descriptor = next((d for d in descriptors.values()
                               if d.get('displayName', '').casefold() == name.casefold() or d.get('name', '').casefold() == name.casefold()), None)
            key = descriptor['name'] if descriptor else name
            if descriptor:
                for option in descriptor.get('allowableValues') or []:
                    option = option.get('allowableValue', option)
                    if option.get('displayName') == value:
                        value = option['value']
                        break
            result[key] = value
        return result

    def create_service(self, group, name, kind, properties):
        entity = self.call('POST', f'/process-groups/{group}/controller-services', {
            'revision': {'version': 0},
            'component': {'name': name, **self.component_type(kind, True)}
        })
        component = entity['component']
        return self.call('PUT', '/controller-services/' + component['id'], {
            'revision': entity['revision'],
            'component': {'id': component['id'], 'properties': self.properties(component['descriptors'], properties)}
        })['component']['id']

    def enable(self, identifier):
        entity = self.call('GET', '/controller-services/' + identifier)
        self.call('PUT', f'/controller-services/{identifier}/run-status', {
            'revision': entity['revision'], 'state': 'ENABLED'
        })
        for _ in range(60):
            component = self.call('GET', '/controller-services/' + identifier)['component']
            if component['state'] == 'ENABLED':
                return
            time.sleep(1)
        raise RuntimeError('Сервис не включился: ' + identifier)


def build(api, group, database):
    schema = json.dumps({'type': 'record', 'name': 'provider', 'fields': [
        {'name': 'id', 'type': 'int'}, {'name': 'name', 'type': 'string'},
        {'name': 'phone', 'type': 'string'}
    ]})
    reader = api.create_service(group, 'JSON reader', 'JsonTreeReader', {
        'Schema Access Strategy': 'Use \'Schema Text\' Property', 'Schema Text': schema
    })
    writer = api.create_service(group, 'JSON writer', 'JsonRecordSetWriter', {
        'Schema Write Strategy': 'Do Not Write Schema', 'Output Grouping': 'Array'
    })
    pool = api.create_service(group, 'PostgreSQL', 'DBCPConnectionPool', {
        'Database Connection URL': f'jdbc:postgresql://{os.getenv("PGHOST", "localhost")}:{os.getenv("PGPORT", "5432")}/{database}',
        'Database Driver Class Name': 'org.postgresql.Driver',
        'Database Driver Location(s)': '/data/drivers/postgresql-42.7.8.jar',
        'Database User': os.getenv('PGUSER', 'artyom'),
        'Password': os.getenv('PGPASSWORD', '123')
    })
    ids = {}
    specs = json.loads((ROOT / 'flow.json').read_text())
    substitutions = {'@reader': reader, '@writer': writer, '@pool': pool,
                     '@schema': (ROOT / 'provider.schema.json').read_text()}
    for index, spec in enumerate(specs):
        entity = api.call('POST', f'/process-groups/{group}/processors', {
            'revision': {'version': 0}, 'component': {
                'name': spec['name'], **api.component_type(spec['type']),
                'position': {'x': (index % 4) * 400, 'y': (index // 4) * 220}
            }
        })
        component = entity['component']
        ids[spec['name']] = component['id']
        properties = {k: substitutions.get(v, v) for k, v in spec.get('properties', {}).items()}
        api.call('PUT', '/processors/' + component['id'], {
            'revision': entity['revision'], 'component': {'id': component['id'], 'config': {
                'properties': api.properties(component['config']['descriptors'], properties),
                'schedulingPeriod': '1 sec', 'concurrentlySchedulableTaskCount': 1,
                'autoTerminatedRelationships': spec.get('terminate', [])
            }}
        })
    for spec in specs:
        for relationship, target in spec.get('connections', {}).items():
            api.call('POST', f'/process-groups/{group}/connections', {
                'revision': {'version': 0}, 'component': {
                    'source': {'id': ids[spec['name']], 'groupId': group, 'type': 'PROCESSOR'},
                    'destination': {'id': ids[target], 'groupId': group, 'type': 'PROCESSOR'},
                    'selectedRelationships': [relationship],
                    'backPressureObjectThreshold': 1000, 'backPressureDataSizeThreshold': '100 MB'
                }
            })
    for identifier in [reader, writer, pool]:
        api.enable(identifier)
    for _ in range(30):
        processors = api.call('GET', f'/process-groups/{group}/processors')['processors']
        if all(p['component'].get('validationStatus') == 'VALID' for p in processors):
            break
        time.sleep(1)
    errors = [(p['component']['name'], p['component'].get('validationErrors'))
              for p in processors if p['component'].get('validationStatus') != 'VALID']
    if errors:
        raise RuntimeError('Проверь настройки процессоров: ' + str(errors))
    return ids


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--url', default='https://localhost:8443')
    parser.add_argument('--database', default=os.getenv('PGDATABASE', 'warehouse'))
    parser.add_argument('--name', default='lab_08')
    parser.add_argument('--start', action='store_true')
    parser.add_argument('--stop', action='store_true')
    args = parser.parse_args()
    api = NiFi(args.url)
    root = api.call('GET', '/flow/process-groups/root')['processGroupFlow']['id']
    groups = api.call('GET', f'/process-groups/{root}/process-groups')['processGroups']
    existing = next((g for g in groups if g['component']['name'] == args.name), None)
    if existing:
        group = existing['id']
        print('Группа уже есть. Ее настройки сохранены:', group)
    else:
        if args.stop:
            raise RuntimeError('Группа еще не создана')
        entity = api.call('POST', f'/process-groups/{root}/process-groups', {
            'revision': {'version': 0}, 'component': {'name': args.name, 'position': {'x': 100, 'y': 100}}
        })
        group = entity['id']
        ids = build(api, group, args.database)
        (ROOT / '.flow-state.json').write_text(json.dumps({'group': group, 'processors': ids}, indent=2))
        print('Flow создан:', group)
    if args.start or args.stop:
        api.call('PUT', f'/flow/process-groups/{group}', {
            'id': group, 'state': 'STOPPED' if args.stop else 'RUNNING'
        })
        print('Flow остановлен' if args.stop else 'Flow запущен')


if __name__ == '__main__':
    main()

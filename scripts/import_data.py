import os
import gzip
import shutil
import json
import sqlite3
import re

def main():
    db_gz_path = 'app_flutter/assets/properties_db.db.gz'
    db_temp_path = 'properties_db.db'
    json_path = 'firestore-export.json'

    print(f"Decompressing {db_gz_path} to {db_temp_path}...")
    with gzip.open(db_gz_path, 'rb') as f_in:
        with open(db_temp_path, 'wb') as f_out:
            shutil.copyfileobj(f_in, f_out)

    print("Connecting to database...")
    conn = sqlite3.connect(db_temp_path)
    cursor = conn.cursor()

    # Disable foreign keys temporarily to allow clean truncate and re-insert
    cursor.execute("PRAGMA foreign_keys = OFF;")

    print("Clearing existing tables...")
    tables = ['properties', 'instances', 'type_definitions', 'type_relations', 'type_attributes']
    for table in tables:
        cursor.execute(f"DELETE FROM {table};")

    print(f"Reading {json_path}...")
    with open(json_path, 'r') as f:
        data = json.load(f)

    nodes = data.get('nodes', [])
    print(f"Found {len(nodes)} nodes to migrate.")

    # Step 1: Identify unique layer names dynamically and insert them
    layers = set()
    for node in nodes:
        layer = node.get('layer')
        if layer:
            layers.add(layer)

    print(f"Identified {len(layers)} unique layers: {layers}")
    for layer in sorted(layers):
        # Register layer in type_definitions with a folder icon
        cursor.execute(
            "INSERT INTO type_definitions (type_name, display_name, icon_name) VALUES (?, ?, ?)",
            (layer, layer, 'folder')
        )
        # Insert layer as root-level node in properties (parent_node_id = NULL)
        cursor.execute(
            "INSERT INTO properties (node_id, parent_node_id, data_json) VALUES (?, ?, ?)",
            (layer, None, '{}')
        )

    # Register the base 'interface' type definition
    cursor.execute('''
        INSERT OR IGNORE INTO type_definitions (type_name, display_name, icon_name)
        VALUES (?, ?, ?)
    ''', ('interface', 'Interface', 'settings'))

    # Register interface attributes under "Interface Config"
    iface_fields = [
        ('name', 'Name', 'string'),
        ('type', 'Type', 'string'),
        ('physAddress', 'Physical Address', 'string'),
        ('enabled', 'Enabled', 'string'),
        ('adminStatus', 'Admin Status', 'string'),
        ('operStatus', 'Oper Status', 'string'),
        ('speed', 'Speed', 'int'),
        ('description', 'Description', 'string')
    ]
    for attr_key, label, attr_type in iface_fields:
        cursor.execute('''
            INSERT OR IGNORE INTO type_attributes 
            (type_name, attr_key, label, attr_type, section_label, section_order, is_required)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', ('interface', attr_key, label, attr_type, 'Interface Config', 0, 0))

    # Helper function for camelCase / dotted split to title case
    def parent_prefix_to_section_label(parent_prefix):
        if not parent_prefix:
            return "General"
        parts = parent_prefix.split('.')
        words = []
        for part in parts:
            subparts = re.findall(r'[A-Za-z][a-z0-9]*', part)
            if not subparts:
                subparts = [part]
            words.extend(subparts)
        return ' '.join(w.capitalize() for w in words)

    def key_to_label(key):
        last_segment = key.split('.')[-1]
        words = re.findall(r'[A-Za-z][a-z0-9]*', last_segment)
        if not words:
            words = [last_segment]
        return ' '.join(w.capitalize() for w in words)

    def get_parent_prefix(key):
        if '.' in key:
            return key.rsplit('.', 1)[0]
        return ''

    def flatten_dict(d, parent_key='', sep='.'):
        items = []
        for k, v in d.items():
            new_key = f"{parent_key}{sep}{k}" if parent_key else k
            if isinstance(v, dict):
                items.extend(flatten_dict(v, new_key, sep=sep).items())
            else:
                items.append((new_key, v))
        return dict(items)

    def flatten_hw(d, parent_key='', sep='.'):
        items = []
        for k, v in d.items():
            new_key = f"{parent_key}{sep}{k}" if parent_key else k
            if isinstance(v, dict):
                items.extend(flatten_hw(v, new_key, sep=sep).items())
            elif isinstance(v, list):
                continue
            else:
                items.append((new_key, v))
        return dict(items)

    # Step 2: Iterate over each node and populate tables
    for node in nodes:
        node_uuid = node.get('uuid')
        node_name = node.get('name')
        node_type = node.get('type')
        node_layer = node.get('layer')
        node_location = node.get('location')

        if not node_uuid:
            continue

        # Extract geodetic coordinates
        geo = node.get('ietfGeoLocation', {})
        loc = geo.get('location', {})
        ellipsoid = loc.get('ellipsoid', {})
        latitude = ellipsoid.get('latitude', 0.0)
        longitude = ellipsoid.get('longitude', 0.0)
        height = ellipsoid.get('height', 0.0)

        # Build properties dictionary
        properties_dict = {k: v for k, v in node.items() if k not in ('uuid', 'hardware', 'ietfInterfaces')}
        properties_dict["position"] = {
            "dim_0": latitude,
            "dim_1": longitude,
            "dim_2": height,
            "time_index": 1.0,
            "vector": [0.0, 0.0, 0.0]
        }
        properties_dict["raw_json"] = json.dumps(node, indent=2)

        # Register the node in type_definitions
        cursor.execute(
            "INSERT INTO type_definitions (type_name, display_name, icon_name) VALUES (?, ?, ?)",
            (node_uuid, node_name, 'dns')
        )

        # Flatten node payload attributes (excluding hardware and ietfInterfaces)
        flat_payload = flatten_dict(properties_dict)
        for attr_key, attr_value in flat_payload.items():
            parent_prefix = get_parent_prefix(attr_key)
            sec_label = parent_prefix_to_section_label(parent_prefix)
            label = key_to_label(attr_key)
            
            if isinstance(attr_value, bool):
                attr_type = 'string'
            elif isinstance(attr_value, int):
                attr_type = 'int'
            elif isinstance(attr_value, float):
                attr_type = 'double'
            else:
                attr_type = 'string'

            cursor.execute('''
                INSERT OR IGNORE INTO type_attributes 
                (type_name, attr_key, label, attr_type, section_label, section_order, is_required)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ''', (node_uuid, attr_key, label, attr_type, sec_label, 0, 0))

        # Insert node row in properties table
        cursor.execute(
            "INSERT INTO properties (node_id, parent_node_id, data_json) VALUES (?, ?, ?)",
            (node_uuid, node_layer, json.dumps(properties_dict))
        )

        # Iterate over hardware components
        hardware_list = node.get('hardware', [])
        for hw in hardware_list:
            hw_uuid = hw.get('uuid')
            hw_name = hw.get('name')
            if not hw_uuid:
                continue

            hw_parent = hw.get('parentUuid')
            if not hw_parent:
                hw_parent = node_uuid

            # Register hardware in type_definitions
            cursor.execute('''
                INSERT OR IGNORE INTO type_definitions (type_name, display_name, icon_name)
                VALUES (?, ?, ?)
            ''', (hw_uuid, hw_name, 'settings'))

            # Flatten hardware attributes and register them in type_attributes
            flat_hw = flatten_hw(hw)
            for attr_key, attr_value in flat_hw.items():
                parent_prefix = get_parent_prefix(attr_key)
                sec_label = parent_prefix_to_section_label(parent_prefix)
                label = key_to_label(attr_key)
                
                if isinstance(attr_value, bool):
                    attr_type = 'string'
                elif isinstance(attr_value, int):
                    attr_type = 'int'
                elif isinstance(attr_value, float):
                    attr_type = 'double'
                else:
                    attr_type = 'string'

                cursor.execute('''
                    INSERT OR IGNORE INTO type_attributes 
                    (type_name, attr_key, label, attr_type, section_label, section_order, is_required)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                ''', (hw_uuid, attr_key, label, attr_type, sec_label, 0, 0))

            # Insert hardware row in properties table
            cursor.execute(
                "INSERT INTO properties (node_id, parent_node_id, data_json) VALUES (?, ?, ?)",
                (hw_uuid, hw_parent, json.dumps(hw))
            )

        # Iterate over interfaces list items
        interfaces_list = node.get('ietfInterfaces', [])
        for iface in interfaces_list:
            iface_name = iface.get('name')
            if not iface_name:
                continue

            # Register relation in type_relations
            cursor.execute('''
                INSERT OR IGNORE INTO type_relations (parent_type_name, relation_name, child_type_name, child_label)
                VALUES (?, ?, ?, ?)
            ''', (node_uuid, 'interfaces', 'interface', 'Interfaces'))

            # Unique interface instance ID
            iface_id = f"{node_uuid}_{iface_name}"

            # Insert interface instance row in instances table
            cursor.execute('''
                INSERT INTO instances (id, parent_node_id, type_name, data_json)
                VALUES (?, ?, ?, ?)
            ''', (iface_id, node_uuid, 'interface', json.dumps(iface)))

    # Re-enable foreign keys and commit
    cursor.execute("PRAGMA foreign_keys = ON;")
    conn.commit()
    conn.close()

    # Verify that the DB file is gzipped back and temporary file is removed
    print(f"Compressing {db_temp_path} back to {db_gz_path}...")
    with open(db_temp_path, 'rb') as f_in:
        with gzip.open(db_gz_path, 'wb') as f_out:
            shutil.copyfileobj(f_in, f_out)

    print(f"Cleaning up {db_temp_path}...")
    if os.path.exists(db_temp_path):
        os.remove(db_temp_path)

    print("Database migration completed successfully!")

if __name__ == '__main__':
    main()

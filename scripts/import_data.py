import os
import gzip
import shutil
import json
import sqlite3

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
        properties_dict = {
            "name": node_name,
            "type": node_type,
            "layer": node_layer,
            "location": node_location,
            "position": {
                "dim_0": latitude,
                "dim_1": longitude,
                "dim_2": height,
                "time_index": 1.0,
                "vector": [0.0, 0.0, 0.0]
            }
        }

        # Register the node in type_definitions
        cursor.execute(
            "INSERT INTO type_definitions (type_name, display_name, icon_name) VALUES (?, ?, ?)",
            (node_uuid, node_name, 'dns')
        )

        # Register dynamic form fields (name, type, layer, location) in type_attributes
        fields_to_register = [
            ('name', 'Name'),
            ('type', 'Type'),
            ('layer', 'Layer'),
            ('location', 'Location')
        ]
        for attr_key, label in fields_to_register:
            cursor.execute('''
                INSERT OR IGNORE INTO type_attributes 
                (type_name, attr_key, label, attr_type, section_label, section_order, is_required)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ''', (node_uuid, attr_key, label, 'string', 'General', 0, 0))

        # Insert node row in properties table
        cursor.execute(
            "INSERT INTO properties (node_id, parent_node_id, data_json) VALUES (?, ?, ?)",
            (node_uuid, node_layer, json.dumps(properties_dict))
        )

        # Iterate over hardware components
        hardware_list = node.get('hardware', [])
        for hw in hardware_list:
            hw_uuid = hw.get('uuid')
            hw_class = hw.get('class')
            if not hw_uuid or not hw_class:
                continue

            # Register hardware class in type_definitions with icon 'settings'
            cursor.execute('''
                INSERT OR IGNORE INTO type_definitions (type_name, display_name, icon_name)
                VALUES (?, ?, ?)
            ''', (hw_class, hw_class.capitalize(), 'settings'))

            # Insert relation row in type_relations matching parent_type_name = node_uuid
            cursor.execute('''
                INSERT OR IGNORE INTO type_relations (parent_type_name, relation_name, child_type_name, child_label)
                VALUES (?, ?, ?, ?)
            ''', (node_uuid, 'contains', hw_class, hw_class.capitalize()))

            # Insert hardware instance row in instances table
            cursor.execute('''
                INSERT INTO instances (id, parent_node_id, type_name, data_json)
                VALUES (?, ?, ?, ?)
            ''', (hw_uuid, node_uuid, hw_class, json.dumps(hw)))

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

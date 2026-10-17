"""Restore the voicenotex MongoDB database from the JSON files in this folder.

Usage (from the backend venv):  python restore_db.py [mongo_uri]
"""
import os
import sys
from pymongo import MongoClient
from bson import json_util

uri = sys.argv[1] if len(sys.argv) > 1 else "mongodb://127.0.0.1:27017"
db = MongoClient(uri)["voicenotex"]
here = os.path.dirname(os.path.abspath(__file__))

for file in os.listdir(here):
    if file.endswith(".json"):
        name = file[:-5]
        with open(os.path.join(here, file), encoding="utf-8") as f:
            docs = json_util.loads(f.read())
        db[name].drop()
        if docs:
            db[name].insert_many(docs)
        print(f"{name}: {len(docs)} documents restored")

#!/usr/bin/env python3
# payload_hash_reader.py codebase is adapted from vm03's payload_dumper.
# To use this, you need to download an up-to-date copy of update_metadata_pb2.py from AOSP sources and place in the same directory as this Python script.
import sys
import argparse
import struct
import os
import zipfile

os.environ["PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION"] = "python"
import update_metadata_pb2

def u32(x):
    return struct.unpack('>I', x)[0]

def u64(x):
    return struct.unpack('>Q', x)[0]

parser = argparse.ArgumentParser()
parser.add_argument('payloadfile', type=argparse.FileType('rb'),
                    help='payload.bin or the zip file containing it')
args = parser.parse_args()

if zipfile.is_zipfile(args.payloadfile):
    args.payloadfile = zipfile.ZipFile(args.payloadfile).open("payload.bin")
args.payloadfile.seek(0)

magic = args.payloadfile.read(4)
file_format_version = u64(args.payloadfile.read(8))

assert magic == b'CrAU'
assert file_format_version == 2

manifest_size = u64(args.payloadfile.read(8))
metadata_signature_size = 0
if file_format_version > 1:
    metadata_signature_size = u32(args.payloadfile.read(4))

manifest = args.payloadfile.read(manifest_size)

dearma = update_metadata_pb2.DeltaArchiveManifest()
dearma.ParseFromString(manifest)

for partition in dearma.partitions:
    print(partition.new_partition_info.hash.hex() + "  " + partition.partition_name + ".img")
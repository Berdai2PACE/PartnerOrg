import xml.etree.ElementTree as ET
import re, copy, sys, os
from shutil import rmtree

def get_namespace(element):
    m = re.match(r'\{.*\}', element.tag)
    return m.group(0) if m else ''

def sanitize(filename):

  folder_name = 'SanitizedPackages'

  if not os.path.exists(folder_name):
    os.makedirs(folder_name)
  else:
    rmtree(folder_name)
    os.makedirs(folder_name)

  package = ET.parse(filename).getroot()

  namespace = get_namespace(package)

  metadata = {}

  total_members = 0

  xml_packages = []

  for type in package.findall(namespace + "types"):

    name = type.find(namespace + "name").text

    for member in type.iter(namespace + "members"):
        if not name in metadata : metadata[name] = {}
        metadata[name][member.text] = ''


  new_xml = ET.Element("Package")

  for metadata_type in metadata:

    members = list(metadata[metadata_type].keys())

    chunks = [members[x:x+10000] for x in range(0, len(members), 10000)]

    for chunk in chunks:

      type = ET.Element('types')
      type_name = ET.Element('name')
      type_name.text = metadata_type

      members_size = len(chunk)

      for member in chunk:
        type_member = ET.Element('members')
        type_member.text = member
        type.append(type_member)

      type.append(type_name)

      if members_size + total_members < 10000 : new_xml.append(type)
      else :
        xml_packages.append(copy.deepcopy(new_xml))

        new_xml = ET.Element("Package")
        new_xml.append(type)
        total_members = 0

      total_members += members_size

  xml_packages.append(new_xml)

  package_version = ET.Element('version')
  package_version.text = package.find(namespace + "version").text

  package_files_nb = 1

  for xml_package in xml_packages:

    xml_package.append(package_version)

    f = open(folder_name + "/package{0}.xml".format(package_files_nb), "w")
    f.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' + ET.tostring(xml_package, encoding="unicode"))
    f.close()

    package_files_nb += 1


if __name__ == '__main__':
    if len(sys.argv) != 2:
      sys.exit(1)

    print("Processing " + sys.argv[1])
    sanitize(sys.argv[1])

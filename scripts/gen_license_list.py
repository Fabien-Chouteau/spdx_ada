import wget
import json
import os

os.path.abspath(__file__)

licenses_url='https://raw.githubusercontent.com/spdx/license-list-data/master/json/licenses.json'
exceptions_url='https://raw.githubusercontent.com/spdx/license-list-data/master/json/exceptions.json'

def get(url):
    with open(wget.download(url)) as json_file:
              return json.load(json_file)

def To_Ada_Id(id):
    if id[0].isnumeric():
        id = 'Id_' + id
    return id.replace('-', '_').replace('.', '_').replace('+', 'p')

def To_Ada_String(str):
    return '"' + str.encode("ascii","ignore").replace('"', '""') + '"'

raw_licenses = get(licenses_url)
licenses_version = raw_licenses['licenseListVersion']
licenses = []

# licenses.append({"id": u"Unknown", 'name': u"Unknown license"})

for lic in raw_licenses['licenses']:
    if not lic['isDeprecatedLicenseId']:
        licenses.append({'id': lic['licenseId'], 'name': lic['name']})


raw_exceptions = get(exceptions_url)
exceptions_version = raw_exceptions['licenseListVersion']
exceptions = []
for lic in raw_exceptions['exceptions']:
    if not lic['isDeprecatedLicenseId']:
        exceptions.append({'id': lic['licenseExceptionId'], 'name': lic['name']})

def gen(package, filename, data, version):
    with open(filename, 'w') as file:
        file.write("package SPDX.%s is\n" % package)
        file.write("\n")
        file.write("   pragma Style_Checks (Off); --  Genrated code\n")
        file.write("\n")
        file.write("   Version : constant String :=\"%s\";\n" % version)
        file.write("\n")
        file.write("   type Id is (\n")
        for i, lic in enumerate(data):
            if i != len(data) - 1:
                file.write("               %s,\n" % To_Ada_Id(lic['id']))
            else:
                file.write("               %s);\n" % To_Ada_Id(lic['id']))
        file.write("\n")
        file.write("   type String_Access is not null access constant String;\n")
        file.write("   Img_Ptr : constant array (Id) of String_Access :=\n")
        file.write("     (\n")
        for i, lic in enumerate(data):
            if i != len(data) - 1:
                file.write ("      %s => new String'(%s),\n" % (To_Ada_Id(lic['id']), To_Ada_String(lic['id'])))
            else:
                file.write ("      %s => new String'(%s));\n" % (To_Ada_Id(lic['id']), To_Ada_String(lic['id'])))
        file.write("\n");
        file.write("   function Img (I : Id) return String\n")
        file.write("   is (Img_Ptr (I).all);\n")
        file.write("\n");
        file.write("   Name_Ptr : constant array (Id) of String_Access :=\n")
        file.write("     (\n")
        for i, lic in enumerate(data):
            if i != len(data) - 1:
                file.write ("      %s => new String'(%s),\n" % (To_Ada_Id(lic['id']), To_Ada_String(lic['name'])))
            else:
                file.write ("      %s => new String'(%s));\n" % (To_Ada_Id(lic['id']), To_Ada_String(lic['name'])))
        file.write("\n");
        file.write("   function Name (I : Id) return String\n")
        file.write("   is (Name_Ptr (I).all);\n")
        file.write("\n");
        file.write("   function Valid_Id (Str : String) return Boolean;\n")
        file.write("   function From_Id (Str : String) return Id;\n")
        file.write("\n");
        file.write("end SPDX.%s;\n" % package)


src_dir=os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'src')
gen('Licenses', os.path.join(src_dir, 'spdx-licenses.ads'), licenses, licenses_version)
gen('Exceptions', os.path.join(src_dir, 'spdx-exceptions.ads'), exceptions, exceptions_version)

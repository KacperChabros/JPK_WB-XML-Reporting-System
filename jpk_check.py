from lxml import etree

xml_file = "my.xml"
xsd_file = "Schemat_JPK_WB(1)_v1-0.xsd"

xml_doc = etree.parse(xml_file)
xsd_doc = etree.parse(xsd_file)
schema = etree.XMLSchema(xsd_doc)

if schema.validate(xml_doc):
    print("XML is valid against XSD.")
else:
    print("There are validation errors:")
    print(schema.error_log)
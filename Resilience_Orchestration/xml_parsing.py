#-------------------------------------------------------------------------------
# Name:        xml_parsing.py
# Purpose:     Resilience and Energy Orchestration Processing
#
# Author:      Karen Angeles kangeles@nd.edu
#
# Created:     09/22/2017

#This script uses the ElementTree XML API to parse xml data for the Green Resilience Project.

#-------------------------------------------------------------------------------

import xml.etree.ElementTree as ET

#First we are going to read through the xml file we are trying to read:
tree=ET.parse('C:/Users/Karen/Desktop/Resilience_Orchestration-master/Resilience_Orchestration-master/TempXMLs/bRC_FRAME_Concrete_allComponents.ifcxml')
root=tree.getroot()
len_root=len(root)
#Grab the last entry of the root --> this is our starting point to get to the Ifc structural data:
start=root[len_root-1] #This creates a class 'xml.etree.ElementTree.Element' object

#The following findall commands identify all of our components: Columns, Beams, Walls
all_colTags=start.findall('{http://www.iai-tech.org/ifcXML/IFC2x2/FINAL}IfcColumn') #This is us asking to find every subelement with the IfcColumn Tag
all_beamTags=start.findall('{http://www.iai-tech.org/ifcXML/IFC2x2/FINAL}IfcBeam') #This is us asking to find every subelement with the IfcBeam Tag
all_WallTags=start.findall('{http://www.iai-tech.org/ifcXML/IFC2x2/FINAL}IfcWallStandardCase') #This is us asking to find every subelement with the IfcWallStandardCase Tag

print("Here are all the columns:")
for tags in all_colTags:
    Tag=tags.find('{http://www.iai-tech.org/ifcXML/IFC2x2/FINAL}Tag').text #This is to verify uniqueness within components
    ObjectType=tags.find('{http://www.iai-tech.org/ifcXML/IFC2x2/FINAL}ObjectType').text
    print(ObjectType,Tag)

print("Here are all the beams:")
for tags in all_beamTags:
    Tag=tags.find('{http://www.iai-tech.org/ifcXML/IFC2x2/FINAL}Tag').text #This is to verify uniqueness within components
    ObjectType=tags.find('{http://www.iai-tech.org/ifcXML/IFC2x2/FINAL}ObjectType').text
    print(ObjectType,Tag)

print("Here are all the walls:")
for tags in all_WallTags:
    Tag=tags.find('{http://www.iai-tech.org/ifcXML/IFC2x2/FINAL}Tag').text #This is to verify uniqueness within components
    ObjectType=tags.find('{http://www.iai-tech.org/ifcXML/IFC2x2/FINAL}ObjectType').text
    print(ObjectType,Tag)










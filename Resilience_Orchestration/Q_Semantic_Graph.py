# -------------------------------------------------------------------------------
# Name:        curves.py
# Purpose:     Use USGS data to create and query hazard curves
#
# Author:      Holly Tina Ferguson hfergus2@nd.edu
#
# Created:     07/20/2017
# Copyright:   (c) Holly Tina Ferguson 2017
# Licence:     The University of Notre Dame

'''
This is what a very basic SPARQL query looks like:

for row in current_vocab_parsed.query("""SELECT ?p ?o  # This is the items or data that you want to get out of the graph
         WHERE { ?s ?p ?o .}""",                       # These are like conditions for selecting which data meets certain requirements
    initBindings={'p' : full_predicate, 's' : s}):     # This is where you get variables from somewhere and set them to be used int he queries
    print "row: ", row                                 # Then you can do and format the data as you want, row returned here is a list

When you need nested queries, you will want to look at online resources, perhaps books, and the many exmaples within the geolinked project
Also, as you will notice below, these couple examples use namespaces (some_vocabulary:term_in_vocab), these are also required (examples are in LD View files)
Lastly, the GSA graph is the defining structure for this graph, so terms like "SpaceBoundary..." come from that respective part of the SGA pattern
There is more about this pattern and how it and the LD Views work in my papers, the other project files, and in my dissertation
'''

# -------------------------------------------------------------------------------

# #!/usr/bin/python
import os
import numpy as np
import rdflib
from rdflib import Graph
from rdflib import URIRef, BNode, Literal
from rdflib.namespace import RDF
from rdflib import Namespace


# Some of the namespaces might be as follows
rdfs_base = "http://www.w3.org/2000/01/rdf-schema#"
xslt_base = "https://www.w3.org/TR/xslt-30/schema-for-xslt30#"
geo_base = "http://www.opengis.net/ont/geosparql#"
xslt_element = URIRef(xslt_base + "element")
xslt_attribute = URIRef(xslt_base + "attribute")
xslt_list = URIRef(xslt_base + "list")
rdfs_isDefinedBy = URIRef(rdfs_base + "isDefinedBy")
geo_hasGeometry = URIRef(geo_base + "hasGeometry")

class GraphData():
    # Input parameters

    def get_all_data(self, USO_New):
        for row in USO_New.query("""SELECT ?s ?p ?o
            WHERE { ?s ?p ?o .}""",
                initBindings={}):
            print "row: ", row

        return

    def get_levels(self, USO_New):
        LevelDict = dict()
        type = URIRef('http://www.sw.org/UBO#hasType')
        value = URIRef('http://www.sw.org/UBO#hasValue')
        counter = 0
        for row in USO_New.query("""SELECT ?sbx ?someProps ?x
            WHERE { ?sbx ?type ?sb .
                    ?sbx ?prop ?someProps .
                    ?someProps ?value ?x
                    }""",
                initBindings={'value': URIRef(value), 'prop': URIRef('http://www.sw.org/UBO#hasProperty'), 'sb': URIRef('http://www.sw.org/UBO#SpaceBoundary'), 'type': URIRef('http://www.w3.org/1999/02/22-rdf-syntax-ns#type')}):
            #print "row: ", row[0], row[2]
            counter += 1
            if row[0] not in LevelDict:
                LevelDict[row[0]] = [row[2]]
            else:
                temp = LevelDict[row[0]]
                temp.append(row[2])
                LevelDict[row[0]] = temp

        #print counter
        return LevelDict

    def get_spaces(self, USO_New):
        spaces_dict = dict()
        for row in USO_New.query("""SELECT ?s ?o
            WHERE { ?s ?p ?o .}""",
                initBindings={'p': URIRef('http://www.sw.org/UBO#hasSpaceMember')}):
            #print "row: ", row
            if row[0] not in spaces_dict:
                spaces_dict[row[0]] = [row[1]]
            else:
                temp = spaces_dict[row[0]]
                temp.append(row[1])
                spaces_dict[row[0]] = temp

        return spaces_dict
    #in the above query --> s (subject) is whatever comes after ns1.
    # p (predicate): since p is being defined with a URI for SpaceMembers, the query will go looking for predicates of hasSpaceMember
    # o (object): what we want back is information about each space... so here o are the different spaces in each SpaceCollection with hasSpaceMember

#In the following query, we are asking for the parser to go through and do the following:
    #1) Go through each subject and select the ones that have a predicate "hasType" = "Column"
    #2) Now that we have identified all of these components, grab the "hasValue" values (literals)...in this case they are a dictionary of all the info for the column
    def get_dim_columns(self, USO_New):
        dimC_dict = dict()
        typeURI = URIRef('http://www.sw.org/UBO#hasType')
        value = URIRef('http://www.sw.org/UBO#hasValue')
        for row in USO_New.query("""SELECT ?s ?info
            WHERE { ?s ?typeURI "Column" .
                    ?s ?value ?info}""",
                initBindings={'typeURI': URIRef('http://www.sw.org/UBO#hasType'),'value':URIRef('http://www.sw.org/UBO#hasValue')}):
            #print "row: ", row
            if row[0] not in dimC_dict:
                dimC_dict[row[0]] = [row[1]]
            else:
                temp = dimC_dict[row[0]]
                temp.append(row[1])
                dimC_dict[row[0]] = temp

        return dimC_dict

#Now doing the same for the beams:

    def get_dim_beams(self, USO_New):
        dimB_dict = dict()
        type = URIRef('http://www.sw.org/UBO#hasType')
        value = URIRef('http://www.sw.org/UBO#hasValue')
        for row in USO_New.query("""SELECT ?s ?info
            WHERE { ?s ?type "Beam" .
                    ?s ?value ?info}""",
                initBindings={'type': URIRef('http://www.sw.org/UBO#hasType'),'value':URIRef('http://www.sw.org/UBO#hasValue')}):
            #print "row: ", row
            if row[0] not in dimB_dict:
                dimB_dict[row[0]] = [row[1]]
            else:
                temp = dimB_dict[row[0]]
                temp.append(row[1])
                dimB_dict[row[0]] = temp

        return dimB_dict

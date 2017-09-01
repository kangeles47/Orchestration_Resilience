#-------------------------------------------------------------------------------
# Name:        main.py
# Purpose:     Resilience and Energy Orchestration Processing
#
# Author:      Holly Tina Ferguson hfergus2@nd.edu
#
# Created:     06/05/2017
# Copyright:   (c) Holly Tina Ferguson 2015
# License:     The University of Notre Dame

# Line 66-71 Below have the directions for asking for an x value along the splines we are able to generate from USGS
# import pymatlab   # This is the library for interfacing with matlab, you will need to install this through the interpreter page
# pymatlab documentation: https://pypi.python.org/pypi/pymatlab
#-------------------------------------------------------------------------------

# #!/usr/bin/python
import sys, os, getopt
import json
import subprocess
import importlib
from os import path
import pandas as pd
#sys.path.append(path.abspath('../GeoLinked'))
#from GeoLinked.Geo_Link import Geo_Link
#x = Geo_Link()
from curves import Curves
import rdflib
from rdflib import Graph
from rdflib import URIRef, BNode, Literal
from rdflib.namespace import RDF
from rdflib import Namespace
#import pymatlab   # This is the library for interfacing with matlab, you will need to install this through the interpreter page

#from pymatlab.matlab import MatlabSession
from Q_Semantic_Graph import GraphData

#Instead of using pymatlab, we will use the methods under the MATLAB API for Python:
import matlab.engine
import numpy as np

#######################################################################################################################
#########################################BEGIN HAZARD MODULE###########################################################

def ReadHazardData(model_names,base_directory):
    """
    modelnames: MUST be same as subdirectory names, or else all hell breaks loose
    base_directory: curves folders generated using the hazard model from USGS
    """
    hazard_data = {} # {city_name: model:[(X1, Y1), ...] }
    for _model in model_names:
        print(_model)
        f = os.path.join(base_directory ,_model,"total.csv")
        df = pd.read_csv(f,header=None) #read in the total.csv file as a dataframe in pandas
        df.drop(df.columns[[1,2]],inplace=True,axis=1) #drop the lat and long
        city_names = df.iloc[:,0].values.tolist()[1:] # all values after the first row are city names
        X = df.iloc[0,1:].values.tolist() #all x values
        for i,c in enumerate(city_names):
            Y = df.iloc[(i+1),1:]
            if c in hazard_data:
                hazard_data[c][_model] = zip(X,Y) #ignore the type assertion for now
            else:
                hazard_data[c] = {_model:zip(X,Y)}
    return hazard_data

def main(argv, other_stuff=0):

    print "Orchestration Main Started"
    print("BEGINNING HAZARD MODULE")
    print("Gathering data from USGS")
    # Take USGS data sets (3 curves) for a location and get back........................................................
    basedir = "C:\\Users\\Karen\\Desktop\\USGS_Resilience-master\\USGS_Resilience-master\\nshmp-haz-master\\curve-making-code\\curves_east_donotmodify"
    #models = ["PGA"] #changed this from line below since we are only asking for one intensity measure (imt)
    models = ["PGA","SA0P2","SA1P0"] #different types of hazard models used
    #read all files
    cityhazardfunctions = ReadHazardData(models,basedir) # nested dict. {city: {model: (X,Y) }}
    #print(json.dumps(cityhazardfunctions,indent=4)) #print to debug if something goes horrendously wrong
    curv = Curves()
    city_splines = curv.querycurves(cityhazardfunctions,savefigs=True)
    # To get the y values for a given list of x's, set these values
    # So, you will set the location from the curve sets we have already generated
    # (for locaiotns we have either see the folders ehre or see the USGS files and sitesE.geojson and sitesW.geojson)
    # The models we have access to set (so the middle term here) without further editing the USGS tool are on line 51 above
    #demo_x = [0.42] #[0.1, 0.2, 0.3, 0.4, 0.5] # So this would be some set of x values you want the cooresponding y values for

    #DEFINE HAZARDS.....................................................................................................
    #Here is where we are going to pull data from the USGS Hazard Curves for PGA, SA1, SA02
    #Essentially, we will be passing vectors into MATLAB for the three curves
    #The "x" subscript refers to spectral acceleration being on the x-axis of the hazard curves
    #The "y" subscript refers to the values for the annual rate of exceedance for the specified spectral accelerations
    #It should be noted that values of 0 to 5 were chosen for the spectral accelerations simply to cover "enough" accelerations for the different regions we are considering in this project


    #We will begin with PGA for the specified location: Chicago IL
    x_values=np.linspace(0,5,50)
    y_values=city_splines["Chicago IL"]["PGA"](x_values)
    PGAx=matlab.double(list(x_values)) #Spectral acceleration values
    PGAy=matlab.double(list(y_values)) #Annual Rate of Exceedance values (Note: these values need to be converted in MATLAB)
    #print(type(SA),type(ARE)) #if uncommented, this will verify that the conversion to a matlab.mlarray.double class was successful

    #Now we repeat the above procedure for SA1, our spectral acceleration for 1.0 second period:
    x_values = np.linspace(0, 5, 50)
    y_values = city_splines["Chicago IL"]["SA1P0"](x_values)
    SA1x = matlab.double(list(x_values))  # Spectral acceleration values
    SA1y = matlab.double(list(y_values))  # Annual Rate of Exceedance values (Note: these values need to be converted in MATLAB)

    #One more time for SA02, our spectral acceleration for 0.2 second period:
    x_values = np.linspace(0, 5, 50)
    y_values = city_splines["Chicago IL"]["SA0P2"](x_values)
    SA02x = matlab.double(list(x_values))  # Spectral acceleration values
    SA02y = matlab.double(list(y_values))  # Annual Rate of Exceedance values (Note: these values need to be converted in MATLAB)

    num_int=float(8) #here we are defining how many intervals (levels of intensity)

    #Last thing: we are going to specify our Soil_Site_class for this site:
    Soil_Site_class='B'

    #Now that we have all of the data we need from our Hazard Curves, we will continue so that we can construct the Semantic Graph and query elevation information
    #...................................................................................................................

    # Construct Semantic Graph..........................................................................................
    print("Constructing Semantic Graph")
    # Currently using locally stored files, will need to add this API automation from my scrips from Drive
    # Note, in script, will need to reset the location of the stored file to be findable by these next lines
    #inputfileIFCXML = Call API script using IronPython
    inputfileIFCXML = 'C:/Users/Karen/Desktop/Resilience_Orchestration-master/Resilience_Orchestration-master/TempXMLs/bRC_FRAME_Concrete_allComponents.ifcxml'
    outputpath='output.csv'
    material_flag = 0
    level_flag = 0
    structure_flag = 0
    puncture_flag = 0
    test_query_sequence_flag = 0
    SemanticGraph_InitialRun = 0
    # Currently using locally stored files, will need to add this API automation from my scrips from Drive
    #geo_link = Geo_Link()
    #geo_link.inputfile = os.path.abspath(inputfileIFCXML)
    #geo_link.material_flag = material_flag
    #geo_link.level_flag = level_flag
    #geo_link.structure_flag = structure_flag
    #geo_link.puncture_flag = puncture_flag
    #geo_link.test_query_sequence_flag = test_query_sequence_flag
    #geo_link.run()
    # Alternatively, a method like this may work, but will need some tweeking as this is done seperately at this point
    mylist_of_parameters = [str(inputfileIFCXML) + " " + str(outputpath) + " " + str(material_flag) + " " + str(level_flag) + " " + str(structure_flag) + " " + str(puncture_flag) + " " + str(test_query_sequence_flag)]
    subprocess.call(["python", "C:/Users/Karen/Desktop/GeoLinked_HollyFerguson-master/GeoLinked_HollyFerguson-master/GeoLmain.pyc", str(inputfileIFCXML), str(outputpath), str(material_flag), str(level_flag), str(structure_flag), str(puncture_flag), str(test_query_sequence_flag) ])
    #subprocess.call(["python", "C:/Users/hfergus2/Desktop/GeoLinked/GeoLmain.py", "--args", str(inputfileIFCXML), str(outputpath), str(material_flag), str(level_flag), str(structure_flag), str(puncture_flag), str(test_query_sequence_flag) ])
    #USO_new = USOmain(inputfileIFCXML, outputpath, material_flag, level_flag, structure_flag, puncture_flag, test_query_sequence_flag)
    print "Storing Graph"
    #store it somewhere...currently we are saving it and accessing it from here: "C:/Users/holly/Desktop/GeoLinked/FinalGraph/MyGraph.ttl"
    #note: make sure to run the specific ifcxml in Geolinked so that the graph is available in the .ttl file specified above before running the orchestration code

    # Query Semantic Graph..............................................................................
    # Now we want to get data from my graph
    # NOTE: more queries will probably have to be written.
    # If you go to this path where the graph serialization was stored, currenlty left in the single room model at the time of this code
    # Then you can see the triples that were able to be pulled out of the GeoLinked project:
    #           "C:/Users/holly/Desktop/GeoLinked/FinalGraph/MyGraph.ttl"
    # If you run other models, they will replace this file above, but if you need multiple runnin,
    # then a versioning system will have to added to the processing, probably back in the GeoLinked Project or running GeoLinked from here
    # For now, this is the process of pulling levels and spaces from the models with SPARQL queries:
    #NOTE: FOR THIS OUTPUT FILE WE NEED TO RUN GEOLINKED WITH THE CORRECT MODEL TO BEGIN WITH
    outputfile = 'C:/Users/Karen/Desktop/GeoLinked_HollyFerguson-master/GeoLinked_HollyFerguson-master/FinalGraph/MyGraph.ttl'  # From the top folder and in FinalGraph
    SGA_Based_Graph = Graph()
    SGA_Based_Graph = SGA_Based_Graph.parse(outputfile, format="turtle")
    #SGA_Based_Graph.serialize(destination=outputfile, format='turtle')
    graph_data = GraphData()
    # I have added a few examples of how you might collect a certain type of data from the graph
    # You will need to add more queries that retrieve and format the information as you see fit per the project needs

    # If uncommented, will print all data in graph so you can learn the structure and what you can and cannot ask it for
    #print "Running All Data Example Query"
    #graph_data.get_all_data(SGA_Based_Graph)

    # If uncommented, will return levels in the building and their heights as a dict: [spaceBoundary: (list of data)]
    # Note: this was modified so that the variable "a" will give us all level information...to see this, uncomment print a in the for loop below
    #print "Running Levels Example Query"
    print("Gathering elevations from graph")
    levels = graph_data.get_levels(SGA_Based_Graph)  # Just copying MyGraph.ttl from other project for now
    a=dict() #this is just here to make sure that we are storing values so that we can filter through our data for when we are querying elevations
    elevations=list()
    for i in levels:
        a=i, len(levels[i]), levels[i] #if we print a, this will give us the full graph for level data
        #print (a)
        value_list=a[2]
        for j in range(len(value_list)): #
            #The idea here is to filter out elevation (z) coordinates by recognizing that these values can be converted into float() type numbers:
            try:
                elevations.append(float(value_list[j]))
            except ValueError:
                pass

    elev=matlab.double(sorted(set(elevations))) #Here we pull unique values from our list and then put them in ascending order
    print("Here are the elevations",elev) #this is here to make sure that we got the correct data

    # If uncommented, will return spaces in their respective building if multi-building: [space_collection: (list of spaces)]
    #print "Running Spaces Example Query"
    #spaces1 = graph_data.get_spaces(SGA_Based_Graph)  # Just copying MyGraph.ttl from other project for now
    #for i in spaces1:
        #print i, len(spaces1[i]), spaces1[i]


    # Call Green Scale..................................................................................................
    # Running t-he GS Tool (it has been updated to 2016 Revit) will need ot be added as this project progresses
    GreenScale_InitialRun = 0 # Change flag once first run is complete
    # Currently using locally stored files, will need to add this API automation from my scrips from Drive
    # Note, in script, will need to reset the location of the stored file to be findable by this next lines
    #inputfileGBXML = Call API script using IronPython
    inputfileGBXML = 'C:/Users/Karen/Desktop/Resilience_Orchestration-master/Resilience_Orchestration-master/TempXMLs/bRC_FRAME_Concrete_allComponents.ifcxml'
    #Call GS Code (will run Thermal and EE), will want to store results plus return a dictinoary of EE values


    # Query for pre-analysis Matlab Module..............................................................................
    print("Beginning MATLAB-SAP API: Modal Analysis")
    # Call Matlab Modules as needed:
    #We call one function, InitHazardModule, in order to conduct the following:
    #(1) Pre-analysis: Modal analysis in SAP --> gives us modal analysis information for ELFM as well as connectivity information. Sets up boundary conditions.
    #(2) Values for spectral accelerations in the x and y for num_int number of intensities as per FEMA Simplified Analysis Procedures
    #(3) Calculation of Equivalent Lateral Forces for Response Module

    eng=matlab.engine.start_matlab() #start MATLAB engine for Python
    eng.cd(r'D:\Users\Karen\Documents\MATLAB\RSB') #Here you specify path to folder where m-file is located
    #Define input variables for the MATLAB function:
    FilePath='D:\Users\Karen\Documents\Revit 2017\RC_FRAME' #this is the file path to the full RC Model, needed for pre-analysis function
    units=3 #Define units


    FrameObjNames,JointCoords, FrameJointConn, FloorConn, WallConn, T1,hj, mass_floor, weight,FilePathResponse,lfm,Dl,Sax,Say,Fj=eng.InitHazardModule(FilePath,units,elev,PGAx,PGAy,SA1x,SA1y,SA02x,SA02y,Soil_Site_class,num_int,nargout=15) #here, the format is as follows: output1, output2, etc=eng.NameOfMFile(Input1,Input2,etc), nargout refers to number of outputs
    print("Results: Hazard Module")
    print("Connectivity Data From SAP:")
    print("Joint Names and Coordinates:",JointCoords)
    print("Frame and Joint Connectivity:",FrameJointConn)
    print("Floor and Joint Connectivity:",FloorConn)
    print("Wall and Joint Connectivity:",WallConn)
    print("Information from Modal Analysis:")
    print("Period in the x and y:",T1)
    print("mass per floor:",mass_floor)
    print("total weight of structure:",weight)
    print("Equivalent Lateral Forces:")
    print(Fj)
    print("END OF HAZARD MODULE")

    #This is the end of the Hazard Module: We now have our Equivalent Static Forces for num_int intensities to conduct our response analysis

    ####################################################################################################################
    #################################BEGINNING OF RESPONSE MODULE#######################################################
    print("BEGINNING RESPONSE MODULE")
    print("Running ELFM")
    #We are now going to implement our equivalent lateral forces from the Hazard Module onto our structure to obtain the response:
    g = float(386)  # here we are defining gravity for in/s^2
    Frame_type='Moment' #here we are defining the type of frame we are analyzing

    eng2=matlab.engine.start_matlab() #start MATLAB engine for Python
    eng2.cd(r'D:\Users\Karen\Documents\MATLAB\RSB') #Here you specify path to folder where m-file is located
    x_disp, y_disp, mean_drift_ratios, mean_accel, B_SD, B_FA, B_FV, B_RD = eng2.InitResponseModule(FrameObjNames,units,FilePathResponse,elev,Fj,num_int,T1,hj,g,PGAx,PGAy,SA1x,SA1y,lfm,Frame_type,nargout=8)
    print("Displacements for All Intensities from SAP")
    print("Displacements in the x:",x_disp)
    print("Displacements in the y:",y_disp)
    print("Actual Displacements and Accelerations (Corrected)")
    print("drifts:",mean_drift_ratios)
    print("accelerations:",mean_accel)
    print('Dispersions')
    print("B_SD:",B_SD)
    print("B_FA:", B_FA)
    print("B_FV:",B_FV)
    print("B_RD:",B_RD)
    print("END OF RESPONSE MODULE")

    ####################################################################################################################
    #################################BEGINNING OF DAMAGE MODULE#######################################################
    print("BEGINNING DAMAGE MODULE")
    #If you need to define a string object, simply type in as follows (without the # at the beginning):
    #variable='StringObject'
    #If you need to pass through a scalar:
    #variable=float(scalarnumber)
    #If you need to pass an array in:
    #variable=matlab.double([indice1, indice2, etc])


    #Make our third call to MATLAB from Python:
    eng3= matlab.engine.start_matlab()  # start MATLAB engine for Python
    eng3.cd(r'D:\Users\Karen\Documents\MATLAB\RSB')  # Here you specify path to folder where m-file is located
    #Basic setup here is output variables = nameoffunction(input variables, output number)
    #So if you need to add more output variables, update nargout value
    #If you need to add more input variables, just add them
    #the only big thing is to make sure that your input/output matches that in your MATLAB file and vice versa
    Cost = eng3.InitDamageModule(mean_drift_ratios,mean_accel,B_SD,B_FA,B_FV,B_RD,num_int,nargout=1) #here nargout is simply the amount of outputs you are asking for
    #if you need to print anything just use the print() function. You can also leave variables uncommented in MATLAB and they will show up below
    print(Cost)





    #print("Working on figuring out how to query semantic graph")
    #levels = graph_data.get_levels(SGA_Based_Graph)  # Just copying MyGraph.ttl from other project for now
    #a = dict()  # this is just here to make sure that we are storing values so that we can filter through our data for when we are querying elevations
    #elevations = list()
    #for i in levels:
        #print  i, len(levels[i]), levels[i]  # if we print a, this will give us the full graph for level data


    print "Main Finished"

if __name__ == "__main__":
    #logging.basicConfig()
    main(sys.argv[1:])
    #main(inputfile, outputfile)





#!/usr/bin/env python

import string,re
import pandas as pd
import numpy as np
#volume strings to parse
# Column element
# "[[<Element {http://www.iai-tech.org/ifcXML/IFC2x2/FINAL}IfcColumn at 0x136b6808>, ('Concrete-Square-Column:14 x 14:528211', 'name'), ('i3438', 'id'), ([('CadID', '528211'), ('world_direction_ratios', ['6.123031769E-17', '1.']), ('depth', ['8.572916667']), ('XandYDim', ['0.08333333333', '0.08333333333']), ('profile_location', ['-3.552713679E-15', '0.']), ('reference_direction', ['1.', '0.']), ('local_direction_ratios', ['-75.50063228', '53.15938446', '10.']), ('position', ['-75.50063228', '53.15938446', '10.']), ('extrude_direction', ['0.', '0.', '1.'])], 'coors')]]" .
# Beam Element
# "[[<Element {http://www.iai-tech.org/ifcXML/IFC2x2/FINAL}IfcBeam at 0x134f3908>, ('Concrete-Rectangular Beam:9x18:528821', 'name'), ('i4255', 'id'), ([('CadID', ['528821']), ('position', []), ('local_direction_ratios', ['1.', '0.', '0.']), ('reference_direction', ['0.', '0.', '0.']), ('profile_location', []), ('XandYDim', ['None', 'None', 'None'])], 'coors')]]" .

#teststr = "[[<Element {http://www.iai-tech.org/ifcXML/IFC2x2/FINAL}IfcBeam at 0x42d66c8>, ('W Shapes:W14X22:587548', 'name'), ('i1963', 'id'), ([('CadID', ['587548']), ('position', ['-76.04229895', '62.6177178', '0.']), ('local_direction_ratios', []), ('reference_direction', []), ('profile_location', ['0.5708333333', '-0.2083333333', '-1.141666667']), ('XandYDim', ['18.85833333', '0.4166666667', '1.141666667'])], 'coors')]]"
#def main():
    #volume = calcvolume(teststr)
    #print(volume)

# Return volume in whatever units are passed in as part of the
# String representing value literal for the Column and Beam Entities in
# the semantic graph object.
def calcvolume(eStr):
    if 'W Shapes' and 'Column' in eStr:
        Isections = pd.read_csv('D:/Users/Karen/Documents/Revit 2016/OMS Building/Model Progression/ifcxmls/ISectionAreas.csv')
        splitstr = eStr.split('(')
        for i in splitstr:
            if 'W Shapes' in i:
                Wname = i.split(':')[1]
                print(Wname)
                #Find the matching name for W shape in CSV file:
                CSV_NAME=Isections.index[Isections['Section']== Wname].tolist()
                thisarea = Isections.Area[float(CSV_NAME[0])] #this is in in^2 for now
            if 'depth' in i:
                thisdepth = i.split("'")[3]
        try:
            farea = float(thisarea)
        except:
            print("Can't cast area to float")

        try:
            fdepth = float(thisdepth)
        except:
            print("Can't cast depth to float")

        volume=fdepth*farea/144 #volume in ft^3

    if 'W Shapes' and 'Beam' in eStr:
        Isections = pd.read_csv('D:/Users/Karen/Documents/Revit 2016/OMS Building/Model Progression/ifcxmls/ISectionAreas.csv')
        splitstr = eStr.split('(')
        for i in splitstr:
            if 'W Shapes' in i:
                Wname = i.split(':')[1]
                print(Wname)
                #Find the matching name for W shape in CSV file:
                CSV_NAME=Isections.index[Isections['Section']== Wname].tolist()
                thisarea = Isections.Area[float(CSV_NAME[0])] #this is in in^2 for now
            if 'XandYDim' in i:
                thisdepth = i.split("'")[3]
        try:
            farea = float(thisarea)
        except:
            print("Can't cast area to float")

        try:
            fdepth = float(thisdepth)
        except:
            print("Can't cast depth to float")

        volume=fdepth*farea/144 #volume in ft^3

    else:
        splitstr = eStr.split('(')
        if 'Column' in splitstr[0]:
            for j in splitstr:
                if 'depth' in j:
                    thisdepth = j.split("'")[3]
                if 'XandYDim' in j:
                    thisx = j.split("'")[3]
                    thisy = j.split("'")[5]
            try:
                fdepth = float(thisdepth)
            except:
                print("Can't cast depth to float")

            try:
                fx = float(thisx)
            except:
                print("Cant cast x value to float")

            try:
                fy = float(thisy)
            except:
                print("Can't cast y value to float")

            volume = fdepth * fx * fy

        if 'Beam' in splitstr[0]:
            print(splitstr[1])
            for i in splitstr:
                if 'XandYDim' in i:
                    thisdepth=i.split("'")[3]
                    thisx = i.split("'")[5]
                    thisy = i.split("'")[7]

            try:
                fdepth = float(thisdepth)
            except:
                print("Can't cast depth to float")

            try:
                fx = float(thisx)
            except:
                print("Cant cast x value to float")

            try:
                fy = float(thisy)
            except:
                print("Can't cast y value to float")

            volume = fdepth * fx * fy

    return volume



#if __name__ == "__main__":
    #main()
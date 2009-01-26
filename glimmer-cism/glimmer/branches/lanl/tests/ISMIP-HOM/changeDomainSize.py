#!/usr/bin/python

#This script takes a glimmer input file and changes the domain size
#to the specified length in meters
#Example: ./changeDomainSize.py ishom.a.config 160000 to run ISMIP-HOM A on
#a 160 km domain
#Assumes that the number of grid points in each direction is one greater than
#the desired (staggered) grid size
#Note that this writes a *copy* of the config file, to (for example) ishom.a.160km.config

import ConfigParser
import sys

#Returns the name of the new config file written
def changeDomainSize(cfgFileName, newDomainSize):
    cfg = ConfigParser.SafeConfigParser()
    cfg.read(cfgFileName)

    #Get the number of grid points in each dimension.  This value will remain constant
    ewn = int(cfg.get("grid","ewn")) - 1
    nsn = int(cfg.get("grid","nsn")) - 1

    #Determine the new grid spacing for the specified domain size
    dew = newDomainSize/ewn
    dns = newDomainSize/nsn

    #Set the file to respect the new domain size
    cfg.set("grid","dew",str(dew))
    cfg.set("grid","dns",str(dns))

    #Change the input and output filenames
    #First, get the prefix (e.g. "ishom.a")
    prefix = cfgFileName.replace(".config","")
    #Create a suffix for this domain size.  For example, running with 160000 should
    #produce the suffix ".160km"
    newDomainSizeStr = str(int(newDomainSize/1000)) + "km"

    prefix += "." + newDomainSizeStr
    cfg.set("CF output", "name", prefix + ".out.nc")
    cfg.set("CF input",  "name", prefix + ".nc")

    #Write out the new config file
    outFileName =cfgFileName.replace(".config","." + newDomainSizeStr + ".config") 
    f = open(outFileName, "w")
    cfg.write(f)
    f.close()
    return outFileName

if __name__ == "__main__":
    cfgFileName = sys.argv[1]
    newDomainSize = float(sys.argv[2])
    changeDomainSize(cfgFileName, newDomainSize)

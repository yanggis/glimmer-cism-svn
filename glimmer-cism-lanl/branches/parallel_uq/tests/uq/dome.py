#!/usr/bin/env python
# This script runs an experiment with an ice "dome".
# Files are written in the "output" subdirectory.
# The script performs the following three steps:
# 1. Create a netCDF input file for Glimmer.
# 2. Run Glimmer, creating a netCDF output file.
# 3. Move any additional files written by Glimmer to the "scratch" subdirectory.
# Written by Glen Granzow at the University of Montana on April 13, 2010

import sys, os, glob, shutil, numpy
from netCDF import *
from math import sqrt
from ConfigParser import ConfigParser

# Check to see if a config file was specified on the command line.
# If not, dome.config is used.
if len(sys.argv) > 1:
  if sys.argv[1][0] == '-': # The filename can't begin with a hyphen
    print '\nUsage:  python dome.py [FILE.CONFIG]\n'
    sys.exit(0)
  else:
    configfile = sys.argv[1]
else:
  configfile = 'dome.config'

# Check to see if #procs specified, relevant when running the code in parallel. 
# If not, serial run (#procs==1) is performed. To run in parallel, the configure
# file must be specifed, but the nu,ber of processors does not
if len(sys.argv) > 2:
    nprocs = sys.argv[2]
else:
  nprocs = '1'

# Create a netCDF file according to the information in the config file.
parser = ConfigParser()
parser.read(configfile)
nx = int(parser.get('grid','ewn'))
ny = int(parser.get('grid','nsn'))
nz = int(parser.get('grid','upn'))
dx = float(parser.get('grid','dew'))
dy = float(parser.get('grid','dns'))
filename = parser.get('CF input', 'name')

print 'Writing', filename
try:
  netCDFfile = NetCDFFile(filename,'w',format='NETCDF3_CLASSIC')
except TypeError:
  netCDFfile = NetCDFFile(filename,'w')

netCDFfile.createDimension('time',1)
netCDFfile.createDimension('x1',nx)
netCDFfile.createDimension('y1',ny)
netCDFfile.createDimension('level',nz)
netCDFfile.createDimension('x0',nx-1) # staggered grid 
netCDFfile.createDimension('y0',ny-1)

x = dx*numpy.arange(nx,dtype='float32')
y = dx*numpy.arange(ny,dtype='float32')

netCDFfile.createVariable('time','f',('time',))[:] = [0]
netCDFfile.createVariable('x1','f',('x1',))[:] = x
netCDFfile.createVariable('y1','f',('y1',))[:] = y
netCDFfile.createVariable('x0','f',('x0',))[:] = dx/2 + x[:-1] # staggered grid
netCDFfile.createVariable('y0','f',('y0',))[:] = dy/2 + y[:-1]

# Calculate values for the required variables.
thk  = numpy.zeros([1,ny,nx],dtype='float32')
topg = numpy.zeros([1,ny,nx],dtype='float32')
artm = numpy.zeros([1,ny,nx],dtype='float32')
acab = numpy.zeros([1,ny,nx],dtype='float32')
bheatflx = numpy.zeros([1,ny,nx],dtype='float32')
beta = numpy.zeros([1,ny-1,nx-1],dtype='float32')

thk[:] = 0.0 
bheatflx[:] = -0.055

# Calculate the thickness of the (ellipsoidal) dome of ice
for i in range(nx-1):
  x = float(i-(nx-1)/2)/(nx-1)
  for j in range(ny-1):
    y = float(j-(ny-1)/2)/(ny-1)
    r_squared = (x*x+y*y)

    if r_squared < 0.120:
      thk[0,j,i] = 1000.0 * sqrt( 1.0 - 8.25*r_squared )
      artm[0,j,i] = 10.0 -20.0/900.0 * thk[0,j,i]               
      acab[0,j,i] = -0.05 * ( 10.0 -20.0/900.0 * thk[0,j,i] )

    else:
      artm[0,j,i] = 8.0              
      acab[0,j,i] = -7.0                                     

beta[:] = 100.0   # constant B^2 

for i in range(nx-2):
  for j in range(ny-2):
      beta[0,j,i] = 100*( thk[0,j,i]+thk[0,j,i+1]+thk[0,j+1,i]+thk[0,j+1,i+1] )/4

#beta[:] = 10000.0   # constant B^2 


# Create the required variables in the netCDF file.
netCDFfile.createVariable('thk', 'f',('time','y1','x1'))[:] = thk
netCDFfile.createVariable('topg','f',('time','y1','x1'))[:] = topg
netCDFfile.createVariable('artm','f',('time','y1','x1'))[:] = artm 
netCDFfile.createVariable('acab','f',('time','y1','x1'))[:] = acab 
netCDFfile.createVariable('bheatflx','f',('time','y1','x1'))[:] = bheatflx 
netCDFfile.createVariable('beta','f',('time','y0','x0'))[:] = beta     

netCDFfile.close()

# Run Glimmer
print 'Running Glimmer/CISM'
if len(sys.argv) > 2:
   os.system('aprun -n'+nprocs+' ./simple_glide '+configfile+'')
else:
   os.system('echo '+configfile+' | simple_glide')

# Clean up by moving extra files written by Glimmer to the "scratch" subdirectory
# Look for files with extension "txt", "log", or "nc"
for files in glob.glob('*.txt')+glob.glob('*.log')+glob.glob('*.nc'):
# Delete any files already in scratch with these filenames 
  if files in os.listdir('scratch'):
    os.remove(os.path.join('scratch',files))
# Move the new files to scratch
  shutil.move(files,'scratch')

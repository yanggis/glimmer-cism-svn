# Copyright 2004, Magnus Hagdorn
# 
# This file is part of GLIMMER.
# 
# GLIMMER is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# GLIMMER is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with GLIMMER; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

"""Handle command line options in a standard way."""

__all__ = ['CFOptParser','CFOptions']

import optparse, sys, PyGMT, os.path
from CF_loadfile import *
from CF_profile import *

class CFOptParser(optparse.OptionParser):
    """Handle options."""

    def __init__(self,usage = "usage: %prog [options] infile outfile"):
        """Initialise.

        usage: usage string.
        """
        optparse.OptionParser.__init__(self,usage)

        self.width = 10.
        try:
            self.rsldb = os.path.join(os.environ['GLIMMER_PREFIX'],'share','PyCF','rsl.db')
        except:
            self.rsldb = None
        
    def plot(self):
        """Plot options."""

        group = optparse.OptionGroup(self,"Plot Options","These options are used to control the appearance of the plot")
        group.add_option("--size",dest="size",default="a4",help="Size of output (default a4)")
        group.add_option("--landscape",action="store_true", dest="landscape",help="select landscape mode")
        group.add_option("--mono",action="store_true",default=False,help="convert colour plots to mono")
        group.add_option("--width",type="float",dest="width",default=self.width, help="width of plot (default %.2f cm)"%(self.width))
        group.add_option("--verbose",action="store_true", dest="verbose",default=False,help="Be verbose")
        self.add_option_group(group)

    def region(self):
        """Specifying region of interest."""

        group = optparse.OptionGroup(self,"Region Options","These options are used to control the region of interest.")
        group.add_option("--llx",dest='llx',metavar="X Y",type="float",nargs=2,help="lower left corner in projected coordinate system")
        group.add_option("--urx",dest='urx',metavar="X Y",type="float",nargs=2,help="upper right corner in projected coordinate system")
        group.add_option("--llg",dest='llg',metavar="X Y",type="float",nargs=2,help="lower left corner in geographic coordinate system")
        group.add_option("--urg",dest='urg',metavar="X Y",type="float",nargs=2,help="upper right corner in geographic coordinate system")
        self.add_option_group(group)

    def eisforcing(self):
        """Options for handling EIS forcing time series."""

        group = optparse.OptionGroup(self,"EIS forcing","Files containing time series used for forcing EIS.")
        group.add_option("--ela",dest='elafile',metavar="FILE",type="string",help="Name of file containing ELA forcing")
        group.add_option("--temp",dest='tempfile',metavar="FILE",type="string",help="Name of file containing temperature forcing")
        group.add_option("--slc",dest='slcfile',metavar="FILE",type="string",help="Name of file containing SLC forcing")
        self.add_option_group(group)

    def __var(self):
        # variable options
        self.add_option("-v","--variable",metavar='NAME',action='append',type="string",dest='vars',help="variable to be processed (this option can be used more than once)")
        self.add_option("-l","--level",metavar="LEV",type='int',dest='level',help='level to be plotted')
        self.add_option("--pmt",action="store_true", dest="pmt",default=False,help='Correct temperature for temperature dependance on pressure')
        
    def variable(self):
        """Variable option."""

        self.__var()
        self.add_option("-c","--clip",metavar='VAR',type="choice",dest='clip',choices=['thk','topg','usurf'],help="display variable only where ['thk','topg','usurf']>0.")
        self.add_option("--land",action="store_true", dest="land",default=False,help="Indicate area above SL")
        try:
            self.add_option("--colourmap",type="string",dest="colourmap",help="name of GMT cpt file to be used (autogenerate one when set to None)")
        except:
            pass
        try:
            self.add_option("--legend",action="store_true", dest="dolegend",default=False,help="Plot a colour legend")
        except:
            pass
        
    def spot(self):
        """Spot options."""

        self.__var()
        self.add_option("-i","--ij",dest='ij',metavar="I J",type="int",nargs=2,action='append',help="node to be plotted (this option can be used more than once)")

    def profile_file(self):
        """Options for profile files."""

        self.add_option("-p","--profile",metavar='PROFILE',type='string',dest='profname',help="name of file containing profile control points")
        self.add_option("--not_projected",action="store_false",default=True,dest="prof_is_projected",help="Set this flag if the profile data is not projected.")        
        self.add_option("--interval",type="float",metavar='INTERVAL',default=10000.,help="set interval to INTERVAL (default = 10000.m)")

    def profile(self,vars=True):
        """Profile options.

        vars: set to False if only profile is needed"""

        if vars:
            self.__var()
        self.profile_file()
        try:
            self.add_option("--colourmap",type="string",dest="colourmap",help="name of GMT cpt file to be used (autogenerate one when set to None)")
        except:
            pass
        try:
            self.add_option("--legend",action="store_true", dest="dolegend",default=False,help="Plot a colour legend")
        except:
            pass
        
    def time(self):
        """Time option."""
        self.add_option("-t","--time",metavar='TIME',action='append',type="float",dest='times',help="time to be processed (this option can be used more than once)")
        self.add_option("-T","--timeslice",metavar='N',action='append',type="int",help="time slice to be processed (this option can be used more than once)")

    def timeint(self):
        """Time interval options."""
        self.add_option("-t","--time",metavar='T0 T1',type="float",nargs=2,dest='times',help="specify time interval T0 T1, if none process entire file.")

    def rsl(self):
        """RSL options."""
        self.add_option("-r","--rsldb",metavar='DB',type="string",default=self.rsldb,help="name of RSL database file [%s]"%self.rsldb)
        self.add_option("--rsl_selection",type="choice",choices=['fenscan'],default='fenscan',help="Change selection of RSL locations to be plotted, can be one of [\"fenscan\"] (default: fenscan)")

class CFOptions(object):
    """Do some option/argument massaging."""

    def __init__(self,parser,numargs=None):
        """Initialise.

        parser: Option parser.
        numargs: the number of arguments expected. A negative numargs implies the minimum number of arguments."""

        (self.options, self.args) = parser.parse_args()

        if numargs != None:
            if numargs>=0:
                if len(self.args)!=numargs:
                    sys.stderr.write('Error, expected %d arguments and got %d arguments\n'%(numargs,len(self.args)))
                    sys.exit(1)
            else:
                if len(self.args)<-numargs:
                    sys.stderr.write('Error, expected at least %d arguments and got %d arguments\n'%(-numargs,len(self.args)))
                    sys.exit(1)
                    
    def __get_nfiles(self):
        return len(self.args)-1
    nfiles = property(__get_nfiles)
    
    def __get_nvars(self):
        try:
            return len(self.options.vars)
        except:
            return 1
    nvars = property(__get_nvars)

    def __get_ntimes(self):
        try:
            return len(self.options.times)
        except:
            return 1
    ntimes = property(__get_ntimes)

    def __get_papersize(self):
        if self.options.landscape:
            orientation = "landscape"
        else:
            orientation = "portrait"
        return PyGMT.PaperSize(self.options.size,orientation)
    papersize = property(__get_papersize)

    def plot(self,argn=-1,number=None):
        """Setup plot.

        argn: number of argument holding output name.
        number: number of series in file"""

        orientation = "portrait"
        try:
            if self.options.landscape:
                orientation = "landscape"
        except:
            pass
    
        if number!=None:
            (root,ext) = os.path.splitext(self.args[argn])
            fname = '%s.%03d%s'%(root,number,ext)
        else:
            fname = self.args[argn]

        try:
            size=self.options.size
        except:
            size="a4"
        plot = PyGMT.Canvas(fname,size=size,orientation=orientation)
        try:
            if self.options.verbose:
                plot.verbose = True
        except:
            pass
        return plot

    def cffile(self,argn=0):
        """Load CF file.

        argn: number of argument holding CF file name."""

        infile = CFloadfile(self.args[argn])

        if hasattr(self.options,'llx'):
            if self.options.llx != None:
                infile.ll_xy = list(self.options.llx)
        if hasattr(self.options,'urx'):
            if self.options.urx != None:
                infile.ur_xy = list(self.options.urx)
        if hasattr(self.options,'llg'):
            if self.options.llg != None:
                infile.ll_geo = list(self.options.llg)
        if hasattr(self.options,'urg'):
            if self.options.urg != None:
                infile.ur_geo = list(self.options.urg)
        
        return infile

    def cfprofile(self,argn=0):
        """Load CF profile.

        argn: number of argument holding CF file name."""

        # load profile data
        xdata = []
        ydata = []
        infile = file(self.options.profname)
        for line in infile.readlines():
            l = line.split()
            xdata.append(float(l[0]))
            ydata.append(float(l[1]))                         
        infile.close()
        profile = CFloadprofile(self.args[argn],xdata,ydata,projected=self.options.prof_is_projected,interval=self.options.interval)

        return profile

    def vars(self,cffile,varn=0):
        """Get variable.

        cffile: CF netCDF file
        varn: variable number
        """

        var = cffile.getvar(self.options.vars[varn])
        try:
            if self.options.colourmap == 'None':
                var.colourmap = '.__auto.cpt'
            elif self.options.colourmap != None:
                var.colourmap = self.options.colourmap
        except:
            var.colourmap = '.__auto.cpt'
        var.pmt = self.options.pmt
        return var

    def profs(self,cffile,varn=0):
        """Get profiles.

        cffile: CF netCDF profile file
        varn: variable number
        """

        prof = cffile.getprofile(self.options.vars[varn])
        prof.pmt = self.options.pmt
        try:
            if self.options.colourmap == 'None':
                prof.colourmap = '.__auto.cpt'
            elif self.options.colourmap != None:
                prof.colourmap = self.options.colourmap
        except:
            prof.colourmap = '.__auto.cpt'
        return prof

    def times(self,cffile,timen=0):
        """Get time slice.

        timen: time number."""

        if self.options.times != None:
            return cffile.timeslice(self.options.times[timen])
        elif self.options.timeslice !=None:
            return self.options.timeslice[timen]
        else:
            return 0

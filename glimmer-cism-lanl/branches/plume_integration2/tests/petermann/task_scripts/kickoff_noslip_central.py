import os

from gcplume import *
from submit_GC_job import *

def kickoff( email, walltime,unique_str, queue_mode ):

    j = LinearShelfJob()
    j.default_flwa = 1.0e-16
    j.uniform_acab = -1.2
    j.n = 30
    j.m = 20
    j.nlevel = 3
    j.tend = 200.0
    j.tstart = 0.0
    j.ice_dt = 0.1
    j.hx = 1000.0
    j.hy = 1000.0
    j.use_plume = 1
    j.plume_dt = 60.0
    j.otopg = -2000.0
    j.upthk = 600.0
    j.ifthk = 550.0
    j.randthk = 0.0

    j.plume = { 'plume_min_thickness' : 50.0,
                }

    j.gc = {'options' : {'flow_law' : 2,
                         'temperature' : 0,
                         },
            'boundary condition params' : {'tau_xy_0' : 50.0e+3,
                                           'x_invariant' : False,
                                           'use_lateral_stress_bc' : False,
                                           },
            'Petermann shelf' : { 'air_temperature' : -20.0,
                                  'accumulation_rate' : j.uniform_acab,
                                  },

            'picard parameters' : {'small_vel' : 0.01,
                                   'minres' : 1.0e-5,
                                   'y_overrideres' : 1.0e-9,
                                   'cvg_accel' : 1.25,
                                   },
            'plume' : {'plume_const_bmlt' : False,
                       'plume_steadiness_tol' : 1.0e-5,
                       },
            }


    oceantemps = [-2.0,-0.5, 0.0, 0.5]
#    oceantemps = [0.0]
    upvels = [-900.0, -1000.0, -1100.0]
#    upvels = [-1000.0]
    phis = [0.0]

    for t in oceantemps:
        for upvel in upvels:
            for phi in phis:

                j.name = 'pn_%.1fC_%.1fma_%.0fd_noslip_%s' % (t,upvel,phi,unique_str)
                
                jdir = os.path.join(os.path.expandvars('$GC_JOBS'),
                                    j.name)

                if (not(os.path.lexists(jdir))):
                    os.mkdir(jdir)
        
                j.jobDir = jdir
            
                j.upvel = upvel
                j.plume = {'temptop' : t,
                           'tempbot' : t,
                           'salttop' : 34.765,
                           'saltbot' : 34.765,
                           'plume_min_thickness' : 25.0,
                           'phi'     : phi}

                j.assertCanStage()
                j.serialize()
                submit_job(j,email, walltime,queue_mode)

USAGE = 'python kickoff_noslip_central.py <unique_str> <queue_mode>'

if __name__ == '__main__':

    if (len(sys.argv) != 3 ):
        raise Exception("Call like: \n %s" % USAGE)
    unique_str = sys.argv[1]
    queue_mode = sys.argv[2]
    
    kickoff('gladish@cims.nyu.edu', '24:00:00',unique_str, 'q')


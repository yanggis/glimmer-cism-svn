#!/usr/bin/python

#
# run Glimmer-cism job
#

import sys
import os.path
import pickle
import subprocess


def readjob(jobfile):

    if (not(os.path.exists(jobfile))):
        raise Exception('ERROR: job file not found')
    g = open(jobfile,'r')
    try:
        j = pickle.load(g)
    finally:
        g.close()
        
    return j


def write_jobscript(j,email,jobfile,walltime):

    #
    # make scripts to run the code
    #

    f = open(os.path.join(os.path.expandvars('$GC_JOB_SCRIPTS'),
                          'run_GC_%s.sh' % j.name),
             'w')

    script = '''#PBS -l nodes=1:ppn=8,walltime=%s
                #PBS -N GC_%s
                #PBS -M %s
                #PBS -m abe
                #PBS -e localhost:%s/\${PBS_JOBNAME}.e
                #PBS -o localhost:%s/\${PBS_JOBNAME}.o

                p=$PWD
                cd %s
                python `which run_job.py` %s
                cd $p
                exit 0;
                EOF
            ''' % (walltime, j.name, email,
                   os.path.expandvars('$GC_JOB_SCRIPTS/'),
                   os.path.expandvars('$GC_JOB_SCRIPTS/'),
                   os.path.dirname(os.path.abspath(jobfile)),
                   os.path.abspath(jobfile))

 
    f.write(script)
    f.close()

def queue_job(mode, j):
    #
    # if queueing job, qsub the script
    #

    runcmd =  os.path.join(os.path.expandvars('$GC_JOB_SCRIPTS'),
                           'run_GC_%s.sh' % j.name)

    if (mode != 'q'):
        print("running job script  %s" % runcmd)
        if (mode == 'fake'):
            pass
        else:
            subprocess.call(['sh', runcmd])
    else:
        print('queueing jobscript: %s' % runcmd)
        retcode = subprocess.call(['qsub', runcmd])
	if (retcode != 0):
	    raise Exception("Error running qsub")

def submit_job(job,email,walltime,mode):
    
    if (type(job) is str):
        j = readjob(job)
    else:
        j = job

    j.assertCanStage()
    write_jobscript(j,email,j.serialFile,walltime)
    
    queue_job(mode,j)

    
def main():

    USAGE="submit_GC_job.sh <job_file> <walltime> <mode>"

    #
    # set user-specific stuff
    #

    EMAIL='gladish@cims.nyu.edu'

    #
    # trap incorrect number of arguments
    #

    if (len(sys.argv) != 4 ):
        print('ERROR: incorrect number of arguments')
        print(USAGE)
        return

    #
    # set variables
    #

    JOB=sys.argv[1]
    print('%s: %s' % ('jobfile', JOB))
    WALLTIME=sys.argv[2]
    print('%s: %s' % ('walltime',WALLTIME))
    MODE=sys.argv[3]
    print('%s: %s' % ('mode', MODE))

    submit_job(JOB,EMAIL,WALLTIME,MODE)


if __name__ == '__main__':
    main()

    

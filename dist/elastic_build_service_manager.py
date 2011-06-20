#!/usr/bin/python
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#   Copyright (C) 2011 Tieto Corporation
#   Contact information: Ville Seppanen, ville.seppanen@tieto.com
#   Updated: 2011-06-20
#   Tested with: OBS 2.1.6, Boto 2.0b4, Python 2.6.5, openSUSE 11.3
#
#
# Elastic Build Service Manager
#
# This script is used to control the cloudbursting of an Elastic Build Service
# that is based on openSUSE Build Service (OBS). The idea is to use virtual
# machines from IaaS providers as build hosts. This script will fetch metrics
# of virtual machines from Amazon Web Services (AWS) as well as build job
# metrics from local OBS server. Based on these metrics this script will
# decide whether to create or destroy virtual machines from AWS EC2. Running
# this script may cost money. This is designed to run as a cron job every
# minute or two.
#
#
# Prerequisites for successfully running this script:
# - AWS account
# - access to an Amazon Machine Image (AMI) that will on startup:
# -- create a VPN tunnel to your OBS server network
# -- start OBS worker(s)
# - private installation of OBS
# - Boto installed http://boto.cloudhackers.com
#
#  Example .boto config:
#    [Credentials]
#    aws_access_key_id = AVTIOJERVAIOEJTIAOTVJ
#    aws_secret_access_key = a369840983a6n03a986bah34098g
#    [Boto]
#    debug = 1
#    num_retries = 3
#    https_validate_certificates = True
#
#  Example .oscrc config:
#    [general]
#    # URL to access API server
#    apiurl = http://localhost:81
#    # run osc to get these auto-generated for you
#    [http://localhost:81]
#    user=exampleuser
#    passx=yzerMZYRNrzyNYZRNYRnxdryXNDRYDXNRY
#
#  Refer to OBS and boto documentation for more help.
#
# TO-DO LIST:
# - fail nicely if AWS or OBS are unreachable or reject requests
# - allow more customization info to be passed through (e.g. IP addresses)
# - use libcloud to avoid AWS lock-in, use separate monitoring software
# - lock the script to prevent multiple running at the same time


import osc.conf # for OBS usage
import osc.core # for OBS usage
from xml.dom import minidom # for XML parsing from OBS API
import boto.ec2 # Python library for EC2 access
import boto.ec2.cloudwatch # for EC2 monitoring info
import boto.utils
from boto.exception import BotoServerError
import time
import datetime # for timestamps
from pprint import pprint # for debug prints
import sys # for arguments


### Configuration variables ###################################################

# Path to log file (if you run this script manually, make sure you have rights
# to write to the log as well)
log_path = "/home/user/build_service_manager.log"

# ID of the AWS Machine Image (AMI) that this script will boot. This image
# should contain obs-worker that autoconnects to your OBS server on boot.
aws_ami_image = "ami-47cefa33"

# AWS keypair to use with the machines. This is needed for SSH connections to
# the workers (which are needed for e.g. debugging).
aws_keypair_name = "MyKeyPair"

# Name of the AWS security group to use. No open ports is ok as your worker
# should create a VPN outwards.
aws_security_group = "MySecurityGroup"

# Type of AWS instance to use. For the first year, t1.micro is free and good
# for testing, but with only 600MB of RAM it fails bigger builds.
# Good choices: t1.micro (for testing), m1.small, c1.medium
aws_instance_type = "m1.small"

# AWS region to use and CloudWatch (AWS monitoring) address to use
aws_cloudwatch_url = "monitoring.eu-west-1.amazonaws.com"
aws_region = "eu-west-1"

# If you want more debugging info than what you get by adding debug=2 to the
# .boto config file, uncomment the following line.
# boto.set_stream_logger('debug')

### Function declarations #####################################################


# Starts a new VM instance in EC2. Parameter obs_worker_id is set as the
# hostname and as EC2 instance metatag "Name" to identify build hosts.
def run_instance(obs_worker_id):

    global print_only
    if not print_only:

        # WARNING: Do NOT start more than 1 instance at a time here!
        # Multilaunching is managed at higher level to create unique tags etc.
        instances_min = 1
        instances_max = 1
        worker_customization = "#!/bin/sh\nhostname " + obs_worker_id +\
            ";echo " + obs_worker_id + " > /etc/HOSTNAME;"

        global aws_ami_image
        global aws_keypair_name
        global aws_security_group
        global aws_instance_type

        reservation = ec2.run_instances(
            image_id = aws_ami_image,
            min_count = instances_min,
            max_count = instances_max,
            key_name = aws_keypair_name,
            security_groups = [aws_security_group],
            user_data = worker_customization,
            instance_type = aws_instance_type)
            #placement='eu-west-1b')

        instance = reservation.instances[0]
        ec2.create_tags([instance.id],{'Name':obs_worker_id})

        global elastic_build_hosts
        elastic_build_hosts.append({'instance_name':obs_worker_id,
                                    'instance_id':instance.id,
                                    'instance_type':instance.instance_type,
                                    'cpu':"-", 'disk':"-",
                                    'instance_state':"SPAWNING",
                                    'launch_time':0,
                                    'time_left':60, 'ip':"-",
                                    'workers':[]})
    return


# Fetches metrics from OBS and EC2 and saves the data to parameters
# elastic_build_hosts and job_status.
def fetch_metrics(elastic_build_hosts, job_status):

    global cloud_buildhost_prefix
    global local_buildhost_prefix
    global aws_cloudwatch_url
    global debug_status_string

    cw = boto.connect_cloudwatch(host=aws_cloudwatch_url,port=443)

    # Get EC2 metrics
    # returns a list of boto.ec2.instance.Reservation
    for machine in ec2.get_all_instances():
        instance = machine.instances[0]

        # tags are not required and thus may not exist
        try:
            name = instance.tags['Name']
        except Exception:
            name = "Unnamed"

        date_now = datetime.datetime.now()
        launch_time = datetime.datetime.strptime(
            instance.launch_time,
            "%Y-%m-%dT%H:%M:%S.000Z")
        time_left = (3600-(((date_now - launch_time).seconds)%3600))/60
        cpu=-1
        ip_address = "-"
        if instance.ip_address != None:
            ip_address = instance.ip_address

            # Fetch instance CPU utilization metrics from CloudWatch
            try:
                end_time = date_now
                start_time = end_time - datetime.timedelta(minutes=15)
                stats = cw.get_metric_statistics(
                    300,
                    start_time,
                    end_time,
                    'CPUUtilization',
                    'AWS/EC2',
                    'Average',
                    {"InstanceId":instance.id})

                # Find latest value from the history list
                latest_value = -1
                latest_time = start_time
                for value in stats:
                    if value['Timestamp'] > latest_time:
                        latest_time = value['Timestamp']
                        latest_value = value['Average']

                # Let's make sure only absolute zero is shown as zero
                if latest_value > 0 and latest_value < 1:
                    cpu = 1
                else:
                    cpu = int(latest_value)

            except BotoServerError as serverErr:
                dbg(json.dumps({
                        "error": "Error retrieving CloudWatch metrics."
                        }))

        if name.startswith(cloud_buildhost_prefix):
            elastic_build_hosts.append({'instance_name':name,
                                        'instance_id':instance.id,
                                        'instance_type':instance.instance_type,
                                        'cpu':cpu, 'disk':-1,
                                        'instance_state':instance.state,
                                        'launch_time':launch_time,
                                        'time_left':time_left, 'ip':ip_address,
                                        'workers':[]})

    # Get OBS metrics
    # Initialize osc configuration, API URL and credentials
    osc.conf.get_config()
    api = osc.conf.config['apiurl']

    apitest = osc.core.http_GET(api + '/build/_workerstatus')
    dom = minidom.parseString(apitest.read())

    # store all idle workers
    for node in dom.getElementsByTagName('idle'):
        build_host_ok = False

        # parse build host id from the worker id
        parsed_hostname = node.getAttribute('workerid')\
            [0:node.getAttribute('workerid').find("/")]

        if parsed_hostname.startswith(cloud_buildhost_prefix):
            # try to find it from the list
            for build_host in elastic_build_hosts:
                if build_host['instance_name'] == parsed_hostname:
                    build_host['workers'].append('IDLE')
                    build_host_ok = True
                    break
        elif parsed_hostname.startswith(local_buildhost_prefix):
            build_host_ok = True # ignore local build hosts
            debug_status_string += "."

        if not build_host_ok:
            dbg("WARN - Strange host " + parsed_hostname)

    # store all busy workers
    for node in dom.getElementsByTagName('building'):
        build_host_ok = False

        # parse build host id from the worker id
        parsed_hostname = node.getAttribute('workerid')\
            [0:node.getAttribute('workerid').find("/")]

        if parsed_hostname.startswith(cloud_buildhost_prefix):
            for build_host in elastic_build_hosts:
                if build_host['instance_name'] == parsed_hostname:
                    build_host['workers'].append(node.getAttribute('package'))
                    build_host_ok = True
                    break
        elif parsed_hostname.startswith(local_buildhost_prefix):
            build_host_ok = True # ignore local build hosts
            debug_status_string += "o"

        if not build_host_ok:
            dbg("WARN - Strange host " + parsed_hostname + " or not building")

    # count the total amount of waiting jobs
    for node in dom.getElementsByTagName('waiting'):
        jobs_status['jobs_waiting_sum'] += int(node.getAttribute('jobs'))

    # count the total amount of blocked jobs
    for node in dom.getElementsByTagName('blocked'):
        jobs_status['jobs_blocked_sum'] += int(node.getAttribute('jobs'))

    return


# Creates the initial connection to AWS EC2 to the region specified in
# parameter region. Region names can be obtained from AWS.
def connect_to_ec2(region):
    connection = boto.ec2.connect_to_region(region)
    dbg("INFO - Connected to: " + connection.host + ":" + str(connection.port))
    dbg("INFO - Secure connection: " + str(connection.is_secure))
    return connection


# Terminates the VM instance in EC2 specified by the instance_id parameter.
def terminate_instance(instance_id):
    global print_only
    if not print_only:
        ec2.terminate_instances([instance_id])
    return


# Prints a table of cloud workers and their status for debugging purposes.
def print_metrics(elastic_build_hosts, job_status):

    print "LISTING ALL BUILD HOSTS\n",'EC2 ID'.ljust(10), 'HOSTNAME'.ljust(14),\
        'TYPE'.ljust(10),'CPU'.ljust(3), 'STATE'.ljust(13), 'TTL'.ljust(3),\
        'IP'.ljust(15), 'CURRENT JOB'
    print "__________________________________________________" +\
        "____________________________________________________"
    for host in elastic_build_hosts:

        workers = "Not connected to OBS"
        if host['instance_state'] == 'stopped' or \
                host['instance_state'] == 'terminated':
            workers = "-"
        if len(host['workers']) > 0:
            workers = ""
            for job in host['workers']:
                workers = workers + job + " "

        # Show time to next bill only if the machine is actually running
        time_left = "-"
        if host['instance_state'] == 'running':
            time_left = str(host['time_left'])

        cpu = "-"
        if host['cpu'] >= 0:
            cpu = str(host['cpu'])

        print host['instance_id'].ljust(10), host['instance_name'].ljust(14),\
        host['instance_type'].ljust(10), cpu.ljust(3), \
        host['instance_state'].ljust(13), \
        time_left.ljust(3), host['ip'].ljust(15), workers
    return


# Prints a debug message if the script is ran in verbose mode and not ran
# with cron-mode.
def dbg(message):
    global cron_mode
    global verbose
    if verbose and not cron_mode:
        print datetime.datetime.now(), message
    return


# Writes a message to a log file, summarizing current situation and showing
# changes made this run. Writes a single line per script run. Appends "MAN"
# to the end of the line if the script was ran manually and not with cron.
def log_write(message):

    global cron_mode
    manual_mode_notice = " MAN"
    if cron_mode:
        manual_mode_notice = ""

    # Log only real actual events and not simulated runs
    global print_only
    global log_path
    if not print_only:
        f = open(log_path, 'a')
        f.write(str(datetime.datetime.now()) + " " + message +
                manual_mode_notice + "\n")
        f.close()
    return


# Starts a new build host and figures out a unique name for it.
def start_new():
    global cloud_buildhost_prefix
    time.sleep(1) # ugly hack to make sure everyone gets a unique name
    obs_worker_id = cloud_buildhost_prefix + str(int(time.time()))[2:]
    run_instance(obs_worker_id)
    return


# This function will decide to either create or terminate instances or to do
# nothing. It will also try to detect various problematic situations.
def analyze_current_situation(elastic_build_hosts, jobs):

    global debug_status_string
    global cloud_buildhost_prefix
    global cron_mode

    # These variables are to balance between efficiency and minimal flapping

    # Time in minutes how close idle workers should live until new fee
    ttl_threshold = 4

    # Max time a host can take to connect to server, must be less than 60 -
    # ttl_threshold. 5 mins should be enough for a normal limit (small booted
    # in 2,5mins). This should also include the time to start a job from the
    # server. 3-5 should be good.
    booting_time = 5

    max_kills_per_run = 5 # Max amount of hosts to terminate on one run
    max_hosts = 15 # Max number of _running_ instances at any time
    max_instances_starting_up = 5 # Max amount of hosts starting at same time
    cpu_too_high = 20 # CPU percentage that is considered too high for idle
    cpu_too_low = 5 # CPU percentage that is considered too low for building

    instances_terminated_this_cycle = 0
    instances_started_this_cycle = 0
    instances_alive = 0 # running, pending, i.e. not shutdown or terminated
    instances_starting_up = 0

    #### KILL BAD AND UNNECESSARY BUILD HOSTS
    # Check what every build host is doing currently and whether it is ok
    for host in elastic_build_hosts:
        # This is implemented in a reverse fashion so that every machine
        # will be terminated unless there is a specific reason to let it live
        should_be_terminated = True
        name = host['instance_name']

        # Check all not terminated workers
        if ((host['instance_state'] == 'running') or \
                (host['instance_state'] == 'pending')) and \
                host['instance_name'].startswith(cloud_buildhost_prefix):

            instances_alive += 1
            workers_total = len(host['workers'])

            # Check connection to OBS server
            if workers_total <= 0:
                dbg("WARN - " + name + " is not connected")
                debug_status_string += "C" # not connected

            else:
                # Count idle workers
                workers_idle = 0
                for worker in host['workers']:
                    if worker == 'IDLE':
                        workers_idle += 1

                # All workers are idle
                if workers_total == workers_idle:
                    if host['cpu'] > cpu_too_high:
                        dbg("WARN - " + name + " has high cpu (" +\
                                str(host['cpu']) + ") for idle. Crashed?")
                    if jobs['jobs_waiting_sum'] > 0:
                        dbg("ERR  - "+name+" has all idle but there's work")
                        debug_status_string += "L" # lazy worker
                    else:
                        if host['time_left'] < ttl_threshold:
                            dbg("OK   - " + name + " idle and time to die.")
                            debug_status_string += "u" # unemployed
                        else:
                            dbg("OK   - " + name + " is idle, wait " +\
                                    str(host['time_left']-ttl_threshold) +\
                                    " more mins")
                            debug_status_string += "i" # idle
                            should_be_terminated = False

                # All workers are working
                elif workers_idle == 0:
                    if host['cpu'] < cpu_too_low:
                        dbg("WARN - " + name + " has quite low cpu (" +\
                                str(host['cpu'])+ ") for building.")
                        debug_status_string += "W" # working + warning
                        should_be_terminated = False
                    else:
                        dbg("OK   - " + name + " has all workers busy.")
                        debug_status_string += "w" # working
                        should_be_terminated = False

                # Some are working and some idling
                else:
                    if jobs['jobs_waiting_sum'] > 0:
                        dbg("WARN  - " + name +\
                                " some workers idle but there's work")
                        debug_status_string += "M" # working + warning
                        should_be_terminated = False
                    else:
                        dbg("OK   - " + name + " some workers idle, no jobs")
                        debug_status_string += "m" # working
                        should_be_terminated = False

            # Terminate extra worker
            age = ((datetime.datetime.now() - host['launch_time']).seconds)/60
            if should_be_terminated:
                if age < booting_time:
                    instances_starting_up += 1
                    dbg("OK   - " + name + " is " + str(age) +\
                            " mins old and may still be starting up. Give it "\
                            + str(booting_time-(60 - host['time_left'])) +\
                            " more minutes to boot.")
                elif instances_terminated_this_cycle >= max_kills_per_run:
                    dbg("WARN - max amount of kills reached.")
                else:
                    instances_terminated_this_cycle += 1
                    instances_alive -= 1
                    dbg("TERM - " + host['instance_id'])
                    terminate_instance(host['instance_id'])
                    host['instance_state'] = "TERMINATING"
                    debug_status_string += "-" # terminating instance

    dbg("INFO - alive:"+str(instances_alive) + ", terminated_this_cycle:" +\
            str(instances_terminated_this_cycle) +", jobs:" +\
            str(jobs['jobs_waiting_sum']) + ", starting:" +\
            str(instances_starting_up))

    #### START NEW BUILD HOSTS IF NEEDED
    if jobs['jobs_waiting_sum'] > 0:
        dbg("OK   - " + str(jobs['jobs_waiting_sum']) + " jobs ready, spawn!")

        # Start more if limits have not been met
        # TODO: This expects that 1 build host == 1 worker == 1 core!
        while (jobs['jobs_waiting_sum']-instances_starting_up) > 0 and \
                (instances_alive <= max_hosts) and \
                (max_instances_starting_up > instances_starting_up):
            start_new()
            instances_alive += 1
            instances_starting_up += 1
            instances_started_this_cycle += 1
            debug_status_string += "+" # starting instance

    dbg("INFO - alive:"+str(instances_alive) + ", started_this_cycle:" +\
            str(instances_started_this_cycle) +", jobs:" +\
            str(jobs['jobs_waiting_sum']) + ", starting:" +\
            str(instances_starting_up))

    #### WRITE TO LOG
    if instances_started_this_cycle > 0 or \
            instances_terminated_this_cycle > 0 or not cron_mode:
        log_write("srvman: job_queue=" + str(jobs['jobs_waiting_sum']) +"+"+\
                      str(jobs['jobs_blocked_sum']) + " [" +\
                      debug_status_string + "]")
    return


### Main script ###############################################################

# Argument handling
print_only = False
cron_mode = False
verbose = False
for arg in sys.argv:
    if arg == "--print-only":
        print_only = True
        break
    elif arg == "--cron-mode":
        cron_mode = True
        break
    elif arg == "--verbose":
        verbose = True
    elif arg == "--help":
        print "Elastic Build Service Manager\nUsage: esm [OPTIONS]\n",\
            " --print-only: no changes are made to the cluster\n",\
            " --cron-mode: no printing, logs cluster changes",\
            " --verbose: print more debug messages in non-cron-mode"
        exit()

# These are used in hostnames to identify different types of build hosts
cloud_buildhost_prefix = "cbh-"
local_buildhost_prefix = "lbh-"

# create datastorages for all metrics
elastic_build_hosts = []
jobs_status = {'jobs_waiting_sum':0,
               'jobs_blocked_sum':0}

debug_status_string = ""

if cron_mode:
    # OBS updates its metrics with cron, let's not fetch metrics from OBS
    # at the same time. Seemed to work ok without this sleep though.
    time.sleep(20)

# connect to a specific EC2 region
ec2 = connect_to_ec2(aws_region)

# fetch all metrics from OBS and EC2
fetch_metrics(elastic_build_hosts, jobs_status)

# figure out current status and what should be done
analyze_current_situation(elastic_build_hosts, jobs_status)

# print metrics for debug usage
if not cron_mode:
    print_metrics(elastic_build_hosts, jobs_status)

#- Templated section: start ------------------------------------------------------------------------
import os
from bifrostlib import datahandling

configfile: "../config.yaml"  # Relative to run directory

bifrost_sampleComponentObj = datahandling.SampleComponentObj()
sample_name, component_name, dockerfile, options, bifrost_resources = bifrost_sampleComponentObj.load(config["sample_id"], config["component_id"])
bifrost_sampleComponentObj.started()
singularity: dockerfile


onsuccess:
    bifrost_sampleComponentObj.load(config["sample_id"], config["component_id"])  # load needed due to bug in snakemake accessing older object
    bifrost_sampleComponentObj.success()


onerror:
    bifrost_sampleComponentObj.load(config["sample_id"], config["component_id"])  # load needed due to bug in snakemake accessing older object
    bifrost_sampleComponentObj.failure()


rule all:
    input:
        # file is defined by datadump function
        component_name + "/datadump_complete"


rule setup:
    output:
        init_file = touch(
            temp(component_name + "/initialized")),
    params:
        folder = component_name


rule_name = "check_requirements"
rule check_requirements:
    message:
        "Running step:" + rule_name
    log:
        out_file = component_name + "/log/" + rule_name + ".out.log",
        err_file = component_name + "/log/" + rule_name + ".err.log",
    benchmark:
        component_name + "/benchmarks/" + rule_name + ".benchmark"
    input:
        folder = rules.setup.output.init_file,
    output:
        check_file = component_name + "/requirements_met",
    params:
        bifrost_sampleComponentObj
    run:
        bifrost_sampleComponentObj.check_requirements()
#- Templated section: end --------------------------------------------------------------------------

#* Dynamic section: start **************************************************************************
rule_name = "ariba_mlst"
rule ariba_mlst:
    # Static
    message:
        "Running step:" + rule_name
    log:
        out_file = rules.setup.params.folder + "/log/" + rule_name + ".out.log",
        err_file = rules.setup.params.folder + "/log/" + rule_name + ".err.log",
    benchmark:
        rules.setup.params.folder + "/benchmarks/" + rule_name + ".benchmark"
    # Dynamic
    input:
        check_file = rules.check_requirements.output.check_file,
        folder = rules.setup.output.init_file,
        reads = bifrost_sampleComponentObj.get_reads()
    output:
        complete = rules.setup.params.folder + "/data.yaml"
    params:
        sampleComponentObj = bifrost_sampleComponentObj
    script:
        os.path.join(os.path.dirname(workflow.snakefile), "scripts/rule__ariba_mlst.py")
#**** Dynamic section: end *************************************************************************

#- Templated section: start ------------------------------------------------------------------------
rule_name = "datadump"
rule datadump:
    # Static
    message:
        "Running step:" + rule_name
    log:
        out_file = component_name + "/log/" + rule_name + ".out.log",
        err_file = component_name + "/log/" + rule_name + ".err.log",
    benchmark:
        component_name + "/benchmarks/" + rule_name + ".benchmark"
    input:
        #* Dynamic section: start ******************************************************************
        rules.ariba_mlst.output.complete  # Needs to be output of final rule
        #* Dynamic section: end ********************************************************************
    output:
        complete = rules.all.input
    params:
        sampleComponentObj = bifrost_sampleComponentObj
    script:
        os.path.join(os.path.dirname(workflow.snakefile), "datadump.py")
#- Templated section: end --------------------------------------------------------------------------
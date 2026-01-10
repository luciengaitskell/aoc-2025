from siliconcompiler import ASIC, Design
from siliconcompiler.targets import skywater130_demo

if __name__ == "__main__":
    design = Design("demo")  # create design object
    design.set_topmodule("top", fileset="rtl")  # set top module
    design.add_file("top.sv", fileset="rtl")  # add input sources
    # design.add_file("top.sdc", fileset="sdc")  # add input sources
    project = ASIC(design)  # create project
    project.add_fileset(
        [
            "rtl",
            #  "sdc",
        ]
    )  # enable filesets
    skywater130_demo(project)  # load a pre-defined target
    # project.option.set_remote(True)  # enable remote execution
    project.run()  # run compilation
    project.summary()  # print summary
    project.show()  # show layout

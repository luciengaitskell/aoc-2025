from siliconcompiler import ASIC, Design
from siliconcompiler.targets import skywater130_demo
from pathlib import Path

from hdl import path as hdl_root

if __name__ == "__main__":
    path = Path(__file__).parent.resolve()
    design = Design("demo")  # create design object
    design.set_topmodule("day08_top", fileset="rtl")  # set top module
    design.add_file(path / "day08_top.sv", fileset="rtl")  # add input sources
    design.add_file(list(hdl_root.glob("*.sv")), fileset="rtl")  # add input sources
    design.add_file(path / "day08_top.sdc", fileset="sdc")  # add input sources
    project = ASIC(design)  # create project
    project.add_fileset(["rtl", "sdc"])  # enable filesets
    skywater130_demo(project)  # load a pre-defined target

    # print(project.getkeys("tool", "yosys"))
    # Enable SystemVerilog support with slang frontend
    project.set("tool", "yosys", "task", "syn_asic", "var", "use_slang", True)

    project.option.set_remote(True)  # enable remote execution
    project.run()  # run compilation
    project.summary()  # print summary
    project.show()  # show layout

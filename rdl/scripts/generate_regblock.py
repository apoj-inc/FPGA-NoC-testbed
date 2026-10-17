import sys

from systemrdl import RDLCompiler, RDLCompileError
from peakrdl_regblock import RegblockExporter
from peakrdl_regblock.cpuif.apb4 import APB4_Cpuif
from peakrdl_regblock.cpuif.avalon import Avalon_Cpuif
from peakrdl_regblock.udps import ALL_UDPS

interface = sys.argv[1]

input_files = []
for arg in sys.argv[2:]:
    input_files.append(f"rdl/src/testbed.{arg}.rdl")

# Create an instance of the compiler
rdlc = RDLCompiler()

# Register all UDPs that 'regblock' requires
for udp in ALL_UDPS:
    rdlc.register_udp(udp)

try:
    # Compile your RDL files
    for input_file in input_files:
        rdlc.compile_file(input_file)

        # Elaborate the design
        root = rdlc.elaborate()

        if interface == "apb":
            # Export a SystemVerilog implementation
            exporter = RegblockExporter()
            exporter.export(
                root, "rtl/gen",
                module_name  = f"testbed_{arg}_am_apb",
                package_name = f"testbed_{arg}_am_pkg",
                default_reset_activelow=True,
                default_reset_async=True,
                cpuif_cls=APB4_Cpuif
            )
        elif interface == "avalon":
            # Export a SystemVerilog implementation
            exporter = RegblockExporter()
            exporter.export(
                root, "rtl/gen",
                module_name  = f"testbed_{arg}_am_avalon",
                package_name = f"testbed_{arg}_am_pkg",
                default_reset_activelow=True,
                default_reset_async=True,
                cpuif_cls=Avalon_Cpuif
            )
        else:
            print("Wrong CPUIF")
            sys.exit(1)

except RDLCompileError:
    # A compilation error occurred. Exit with error code
    sys.exit(1)
export RUN_DIR="/vradfo/test/exe"
dd_IEREF="/vradfo/test/control/reffile/DFO_error_desc.ref"
dd_OEREF="/vradfo/test/control/reffile/DFO_error_desc_index.ref"

export dd_IEREF dd_OEREF

cobrun '$RUN_DIR/crteindx.int'


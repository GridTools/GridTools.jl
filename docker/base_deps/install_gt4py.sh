#!/bin/bash
git clone --branch fix_python_interp_path_in_cmake https://github.com/tehrengruber/gt4py.git
pip install -r ./gt4py/requirements-dev.txt
pip install ./gt4py
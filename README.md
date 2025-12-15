# VLEO Numerical Simulator

This project folder contains all scripts and code-related documents that were used to develop the Master Thesis.

## Requirements
* MATLAB >= R2025a with:
  * Aerospace Blockset
  * Aerospace Toolbox
  * Computer Vision Toolbox
  * Control System Toolbox
  * Image Processing Toolbox
  * Navigation Toolbox
  * Signal Processing Toolbox
  * Simulink

* Python 3.11

**N.B.** Different versions may work but have not been tested yet!

## MATLAB configuration
This repo is managed via a MATLAB project. To run any code without having path issues simply open the [VLEO_numerical_simulator.prj](https://github.com/achille-ballabeni/VLEO_numerical_simulator/blob/main/VLEO_numerical_simulator.prj) file.

## Python setup
Some analysis require the execution of Python scripts. To get started:

1) Create a virtual environment with the required Python version

```console
python3.11 -m venv env
```

2) Activate environment

```console
env/Scripts/activate
```

3) Install dependencies

```console
pip install -r requirements.txt
```



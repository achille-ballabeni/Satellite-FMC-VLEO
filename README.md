# Numerical Simulation of Satellite Forward Motion Compensation

This project folder contains all scripts and code-related documents that were used to develop the master thesis: "Numerical Simulation of Satellite Forward Motion Compensation".
Further documentation will be added once the thesis is published.

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

* Python 3.11 (https://www.python.org/downloads/)

**N.B.** Different versions may work but have not been tested yet!

**N.B.** The _image_processing()_ class only works on Windows because it runs the sixsV1.1 executable that was compiled on a Windows machine.

## MATLAB configuration
This repo is managed via a MATLAB project. To run any code without having path issues simply open the [VLEO_numerical_simulator.prj](https://github.com/achille-ballabeni/VLEO_numerical_simulator/blob/main/VLEO_numerical_simulator.prj) file.

## Python setup
Some analysis require the execution of Python scripts. To get started:

1) Open a terminal in the folder where you downloaded the repository.

2) Create a virtual environment with the required Python version:

```console
python3.11 -m venv env
```

3) Activate the environment:

```console
.\env\Scripts\activate (Windows)
```
```console
. env/bin/activate (Linux/macOS)
```

4) Install dependencies:

```console
pip install -r requirements.txt
```



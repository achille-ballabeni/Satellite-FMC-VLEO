import argparse
import math
from pathlib import Path

import sensors.quantum_efficiency as quantum_efficiency
from Py6S import (
    AeroProfile,
    Altitudes,
    AtmosProfile,
    Geometry,
    GroundReflectance,
    SixS,
    Wavelength,
)

# Parse arguments
parser = argparse.ArgumentParser()
parser.add_argument(
    "--sixs_path",
    type=str,
    default=Path("D:\\AKO\\UNI_AERO\\Tesi_Magistrale\\VLEO_numerical_simulator\\src\\analysis\\radiative_transfer\\6SV1.1\\sixsV1.1"),
    help="Path to SixS installation",
)
parser.add_argument(
    "--sensor",
    type=str,
    default="CMV12000",
    choices=["CMV12000", "IMX249"],
    help="Sensor name",
)
parser.add_argument(
    "--compute_saturation",
    action="store_true",
    help="Compute saturation time with hardcoded parameters",
)


args = parser.parse_args()
sixs_path = Path(args.sixs_path)

# Create a SixS object called s (used as the standard name by convention)
s = SixS(path=sixs_path)

# Setting parameters
s.atmos_profile = AtmosProfile.PredefinedType(AtmosProfile.MidlatitudeSummer)
s.aero_profile = AeroProfile.PredefinedType(AeroProfile.Urban)
# I'm basically saying that a pixel whose value is 1 has a reflectance of
# 0.3. The best way would be to get the brightest object reflectance and
# scale from that.
s.ground_reflectance = GroundReflectance.HomogeneousLambertian(0.3)
s.altitudes = Altitudes()
s.altitudes.set_target_sea_level()
s.altitudes.set_sensor_satellite_level()
s.geometry = Geometry.User()

s.geometry.solar_z = 50  # Corresponding to 10:30 LTDN + 46° latitude -> Skysat, Pleiades Neo, Spot (10:00)
s.geometry.solar_a = 0  # Doesn't matter as long as nadir pointing
s.geometry.view_z = 0  # SSO always pointing nadir
s.geometry.view_a = 0  # Doesn't matter as long as nadir pointing
s.geometry.day = 1
s.geometry.month = 1  # Earth sun distance changes, max flux at winter
year = 2003

lat = 46
date = "{}-{}-{} 01:00".format(year, s.geometry.month, s.geometry.day)
s.atmos_profile = AtmosProfile.FromLatitudeAndDate(lat, date)

# Spring equinox to find a reference geometry
# s.geometry.from_time_and_location(45,166.85-22.5,"2003-03-21 01:00",0,0)

# Set sensor
qe = quantum_efficiency.QE()
if args.sensor == "CMV12000":
    qe.CMV12000()
elif args.sensor == "IMX249":
    qe.IMX249()
else:
    raise ValueError("Unsupported sensor name. Use IMX249 or CMV12000.")

# Set camera
f = 580e-3  # [m]
d = 95e-3  # [m]
px = 5.5e-6  # [m]
tau = 1
well = 13500

# Wavelength range and QE
wl_min = qe.wl_min / 1000
wl_max = qe.wl_max / 1000

colors = [qe.red, qe.green, qe.blue]
labels = ["RED", "GREEN", "BLUE"]
matlab_output = []

for color, label in zip(colors, labels):

    # Print header
    print("### " + label + " band ###")

    # Run 6SV
    s.wavelength = Wavelength(wl_min, wl_max, color)
    s.run()

    # Simulation outputs
    electron_flux = s.outputs.apparent_radiance  # [electrons/m^2*m*sr]
    deltaL = s.outputs.int_funct_filt

    # Setup MATLAB output
    out_dict = {
        "color": label,
        "electron_flux": electron_flux,
        "integrated_filter_function": deltaL,
    }
    matlab_output.append(out_dict)

    if args.compute_saturation:
        # Compute saturation time
        electrons_ppx = (
            electron_flux * deltaL * math.pi / 4 * (d / f) ** 2 * tau * px**2
        )
        saturation_time = well / electrons_ppx * 1e6  # [microseconds]

        # Show results
        print("Electron flux [electrons/m^2*m*sr]: " + str(electron_flux))
        print("Integrated filter function [m]: " + str(deltaL))
        print("Electrons rate per pixel [electrons/s]: " + str(electrons_ppx))
        print("Saturation time [microseconds]: " + str(saturation_time))
    else:
        print("Electron flux [electrons/m^2*m*sr]: " + str(electron_flux))
        print("Integrated filter function [m]: " + str(deltaL))

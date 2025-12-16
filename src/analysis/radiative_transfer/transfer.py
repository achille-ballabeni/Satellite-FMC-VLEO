import argparse
import math
from pathlib import Path

import sensors.quantum_efficiency as quantum_efficiency
from Py6S import (
    AeroProfile,
    Altitudes,
    AtmosProfile,
    GroundReflectance,
    SixS,
    Wavelength,
)


def run_cli():

    # Parse arguments
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-p",
        "--sixs_path",
        type=str,
        default=Path(
            "D:\\AKO\\UNI_AERO\\Tesi_Magistrale\\VLEO_numerical_simulator\\src\\analysis\\radiative_transfer\\6SV1.1\\sixsV1.1"
        ),
        help="Path to SixS installation",
    )
    parser.add_argument(
        "-s",
        "--sensor",
        type=str,
        default="CMV12000",
        choices=["CMV12000", "IMX249"],
        help="Sensor name",
    )
    parser.add_argument(
        "-m",
        "--month",
        type=int,
        default=1,
        choices=[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
        help="Set month for flux computation.",
    )
    parser.add_argument(
        "-b",
        "--beta_angle",
        type=float,
        default=22.5,
        help="Beta angle: sun-earth-satellite. Default corresponds to orbital geometry of Skysat and Pleiades Neo",
    )
    parser.add_argument(
        "-l",
        "--latitude",
        type=float,
        default=46,
        help="Satellite latitude.",
    )
    parser.add_argument(
        "-sat",
        "--compute_saturation",
        action="store_true",
        help="Compute saturation time with hardcoded parameters",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Verbosity",
    )

    return parser.parse_args()


if __name__ == "__main__":

    # Run cli interface
    args = run_cli()

    # Set path to sixs
    sixs_path = Path(args.sixs_path)

    # Create a SixS object called s (used as the standard name by convention)
    s = SixS(path=sixs_path)

    # 6SV configuration parameters
    s.atmos_profile = AtmosProfile.PredefinedType(AtmosProfile.MidlatitudeSummer)
    s.aero_profile = AeroProfile.PredefinedType(AeroProfile.Urban)
    # I'm basically saying that a pixel whose value is 1 has a reflectance of
    # 0.3. The best way would be to get the brightest object reflectance and
    # scale from that.
    s.ground_reflectance = GroundReflectance.HomogeneousLambertian(0.3)
    s.altitudes = Altitudes()
    s.altitudes.set_target_sea_level()
    s.altitudes.set_sensor_satellite_level()

    # Spring equinox to find a reference geometry
    equinox_GMT = "2025-03-20 10:01:03"
    s.geometry.from_time_and_location(
        lat=args.latitude,
        lon=31.575 - args.beta_angle,
        datetimestring=equinox_GMT,
        view_z=0,
        view_a=0,
    )
    s.geometry.solar_a = 0  # Doesn't matter as long as nadir pointing
    s.geometry.day = 1
    s.geometry.month = args.month  # Earth sun distance changes, max flux at winter
    year = 2025

    date = "{}-{}-{} 10:01".format(year, s.geometry.month, s.geometry.day)
    s.atmos_profile = AtmosProfile.FromLatitudeAndDate(args.latitude, date)

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
        if args.verbose:
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
            if args.verbose:
                print("Electron flux [electrons/m^2*m*sr]: " + str(electron_flux))
                print("Integrated filter function [m]: " + str(deltaL))
                print("Electrons rate per pixel [electrons/s]: " + str(electrons_ppx))
                print("Saturation time [microseconds]: " + str(saturation_time))
        else:
            if args.verbose:
                print("Electron flux [electrons/m^2*m*sr]: " + str(electron_flux))
                print("Integrated filter function [m]: " + str(deltaL))

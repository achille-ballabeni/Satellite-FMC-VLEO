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

# Create a SixS object called s (used as the standard name by convention)
path = Path(__file__).parent
sixs_path = path / "6SV1.1" / "sixsV1.1"
s = SixS(path=sixs_path)
# s = SixS()

# Setting parameters
s.atmos_profile = AtmosProfile.PredefinedType(AtmosProfile.MidlatitudeSummer)
s.aero_profile = AeroProfile.PredefinedType(AeroProfile.Urban)
s.ground_reflectance = GroundReflectance.HomogeneousLambertian(
    0.3
)  # I'm basically saying that a pixel whose value is 1 has a reflectance of 0.3. The best way would be to get the brightest object reflectance and scale from that.
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
qe.IMX249()
wl_min = qe.wl_min / 1000
wl_max = qe.wl_max / 1000

color_r = qe.red
color_g = qe.green
color_b = qe.blue

# Run 6SV
s.wavelength = Wavelength(wl_min, wl_max, color_b)
s.run()
s.outputs.write_output_file("test")

# Post-processing
f = 50e-3  # [m]
d = 4.45e-3  # [m]
px = 5.86e-6  # [m]
tau = 1
well = 33624

photon_flux = s.outputs.apparent_radiance  # [electrons/m^2*m*sr]
deltaL = s.outputs.int_funct_filt

photons_ppx = photon_flux * deltaL * math.pi / 4 * (d / f) ** 2 * tau * px**2
saturation_time = well / photons_ppx * 1e6  # [microseconds]

print(photons_ppx)
print(saturation_time)
print(photon_flux)
print(deltaL)

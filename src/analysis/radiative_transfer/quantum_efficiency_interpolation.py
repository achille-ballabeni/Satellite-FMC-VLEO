import matplotlib.pyplot as plt
import numpy as np
from scipy import interpolate
from sensors import quantum_efficiency

# Sensor QE data
qe = quantum_efficiency.QE()
qe.CMV12000()
xmin = qe.wl_min
xmax = qe.wl_max

# Original data with 50nm spacing
wavelengths_r = np.array(qe.red_wl_RAW)
wavelengths_g = np.array(qe.green_wl_RAW)
wavelengths_b = np.array(qe.blue_wl_RAW)
# Define RGB values at 50nm intervals (read from plot)
color_r = np.array(qe.red_RAW)
color_g = np.array(qe.green_RAW)
color_b = np.array(qe.blue_RAW)


# Clean arrays
def clean_array(a):
    a = a[a != -1]
    return a


wavelengths_r = clean_array(wavelengths_r)
wavelengths_g = clean_array(wavelengths_g)
wavelengths_b = clean_array(wavelengths_b)
color_r = clean_array(color_r)
color_g = clean_array(color_g)
color_b = clean_array(color_b)

# Create interpolation functions (cubic spline)
interp_r = interpolate.interp1d(
    wavelengths_r, color_r, kind="cubic", bounds_error=False, fill_value="extrapolate"
)
interp_g = interpolate.interp1d(
    wavelengths_g, color_g, kind="cubic", bounds_error=False, fill_value="extrapolate"
)
interp_b = interpolate.interp1d(
    wavelengths_b, color_b, kind="cubic", bounds_error=False, fill_value="extrapolate"
)

# Generate 2.5nm spacing
wavelengths_2_5nm = np.arange(xmin, xmax + 0.1, 2.5)

# Interpolate
color_r_interp = interp_r(wavelengths_2_5nm)
color_g_interp = interp_g(wavelengths_2_5nm)
color_b_interp = interp_b(wavelengths_2_5nm)

# Ensure non-negative values
color_r_interp = np.maximum(color_r_interp, 0)
color_g_interp = np.maximum(color_g_interp, 0)
color_b_interp = np.maximum(color_b_interp, 0)

print(color_r_interp)
print(color_g_interp)
print(color_b_interp)

plt.figure(figsize=(10, 6))
plt.plot(wavelengths_2_5nm, color_r_interp, "r-", label="Red", linewidth=2)
plt.plot(wavelengths_2_5nm, color_g_interp, "g-", label="Green", linewidth=2)
plt.plot(wavelengths_2_5nm, color_b_interp, "b-", label="Blue", linewidth=2)
plt.xlabel("Wavelength [nm]")
plt.ylabel("Absolute QE")
plt.legend()
plt.grid(True)
plt.show()

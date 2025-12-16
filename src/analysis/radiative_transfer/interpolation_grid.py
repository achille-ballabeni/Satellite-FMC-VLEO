from pathlib import Path

import matplotlib.image as mpimg
import matplotlib.pyplot as plt

name = "IMX249.jpg"
path = Path(__file__).parent
filepath = path / "sensors" / name

# Path to graph you want to generate interpolation grid from
img = mpimg.imread(filepath)

# Set boundaries: must be the same values spanned in the graph
xmin = 400
xmax = 1000
ymin = 0
ymax = 0.7

# Initialize figure
fig, ax = plt.subplots()

# Map image onto real axes
ax.imshow(img, extent=[xmin, xmax, ymin, ymax], aspect="auto")

ax.set_title("Click points")
ax.set_xlim(xmin, xmax)
ax.set_ylim(ymin, ymax)

# Grid with spacing: set spacing to match the same in the original picture
# for confirmation
x_spacing = 50  # [nm]
y_spacing = 10  # [%]
ax.set_xticks(range(xmin, xmax + 1, x_spacing))
ax.set_yticks([i / 100 for i in range(0, int(ymax * 100 + 1), y_spacing)])
ax.grid(True, linestyle="--", alpha=0.5)

clicked_x = []
clicked_y = []


def onclick(event):
    if event.inaxes:
        x, y = event.xdata, event.ydata
        clicked_x.append(x.item())
        clicked_y.append(y.item())
        print(f"x={x:.2f}, y={y:.3f}")


fig.canvas.mpl_connect("button_press_event", onclick)

plt.show()

print("\nSelected points:")
print(clicked_x)
print(clicked_y)

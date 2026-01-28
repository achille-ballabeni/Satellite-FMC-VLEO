from pathlib import Path

import matplotlib.image as mpimg
import matplotlib.pyplot as plt
import numpy as np
from scipy import interpolate


class QEinterpolator:
    def __init__(
        self, name=None, image_path=None, xmin=None, xmax=None, ymin=None, ymax=None
    ):
        """
        Parameters
        ----------
        name : str, optional
            Name string
        image_path : str or Path, optional
            Path to sensor QE plot image
        xmin, xmax : float, optional
            Wavelength bounds [nm]
        ymin, ymax : float, optional
            QE bounds (absolute values)
        """
        self.name = name
        self.image_path = Path(image_path) if image_path else None
        self.xmin, self.xmax = xmin, xmax
        self.ymin, self.ymax = ymin, ymax
        self.raw_data = {"r": [], "g": [], "b": []}
        self.interp_data = None

    def click_points(self, x_spacing=50, y_spacing=0.1, color="RED"):
        """Interactive point selection on image grid."""
        img = mpimg.imread(self.image_path)
        fig, ax = plt.subplots(figsize=(12, 7))
        ax.imshow(
            img, extent=[self.xmin, self.xmax, self.ymin, self.ymax], aspect="auto"
        )
        ax.set_title("Click points for " + color + " curve.")
        ax.set_xlabel("Wavelength [nm]")
        ax.set_ylabel("Absolute QE")
        ax.set_xlim(self.xmin, self.xmax)
        ax.set_ylim(self.ymin, self.ymax)
        ax.set_xticks(np.arange(self.xmin, self.xmax + 1, x_spacing))
        ax.set_yticks(np.arange(self.ymin, self.ymax + 0.01, y_spacing))
        ax.grid(True, linestyle="--", alpha=0.5)

        clicks = {"x": [], "y": []}

        def onclick(event):
            if event.inaxes:
                clicks["x"].append(event.xdata)
                clicks["y"].append(event.ydata)
                ax.plot(event.xdata, event.ydata, "ko", markersize=4)
                fig.canvas.draw()
                print(f"λ={event.xdata:.1f} nm, QE={event.ydata:.4f}")

        fig.canvas.mpl_connect("button_press_event", onclick)
        plt.show()

        return np.array(clicks["x"]), np.array(clicks["y"])

    def set_raw_data(self, wl_r, qe_r, wl_g, qe_g, wl_b, qe_b):
        """Manually set raw data points."""
        self.raw_data = {
            "r": (np.array(wl_r), np.array(qe_r)),
            "g": (np.array(wl_g), np.array(qe_g)),
            "b": (np.array(wl_b), np.array(qe_b)),
        }

    def interpolate(self, wl_start=400, wl_end=1000, spacing=2.5, kind="cubic"):
        """
        Interpolate QE curves to uniform grid.

        Parameters
        ----------
        wl_start, wl_end : float
            Wavelength range [nm]
        spacing : float
            Grid spacing [nm]
        kind : str
            Interpolation type ('linear', 'cubic')
        """
        wl_interp = np.arange(wl_start, wl_end + spacing, spacing)
        result = {"wl": wl_interp}

        for color in ["r", "g", "b"]:
            wl_raw, qe_raw = self.raw_data[color]
            # # Remove invalid entries
            # mask = (wl_raw != -1) & (qe_raw != -1)
            # wl_clean = wl_raw[mask]
            # qe_clean = qe_raw[mask]

            f = interpolate.interp1d(
                wl_raw,
                qe_raw,
                kind="cubic",
                bounds_error=False,
                fill_value="extrapolate",
            )
            result[color] = np.maximum(f(wl_interp), 0)

        self.interp_data = result
        return result

    def save_csv(self, filename=None):
        """Save raw and interpolated data to CSV."""
        if self.interp_data is None:
            raise ValueError("Run interpolate() first")

        # Pad raw data to match interpolated length
        n = len(self.interp_data["wl"])
        pad = lambda arr: np.pad(arr, (0, max(0, n - len(arr))), constant_values=-1)[:n]

        data = np.column_stack(
            [
                pad(self.raw_data["r"][0]),
                pad(self.raw_data["r"][1]),
                pad(self.raw_data["g"][0]),
                pad(self.raw_data["g"][1]),
                pad(self.raw_data["b"][0]),
                pad(self.raw_data["b"][1]),
                self.interp_data["wl"],
                self.interp_data["r"],
                self.interp_data["g"],
                self.interp_data["b"],
            ]
        )

        filename = self.name if filename is None else filename
        np.savetxt(
            "QE_" + filename + ".csv",
            data,
            delimiter=",",
            header="wl_r_RAW,qe_r_RAW,wl_g_RAW,qe_g_RAW,wl_b_RAW,qe_b_RAW,"
            "wl,qe_r,qe_g,qe_b",
            comments="",
        )
        print(f"Saved to {filename}")

    @staticmethod
    def plot(csv_file=None, show_raw=False):
        """
        Plot interpolated QE curves.

        Parameters
        ----------
        csv_file : str, optional
            Load from CSV instead of memory
        show_raw : bool
            Show raw data points
        """
        if csv_file:
            data = np.loadtxt(csv_file, delimiter=",", skiprows=1)
            wl = data[:, 6]
            qe_r, qe_g, qe_b = data[:, 7], data[:, 8], data[:, 9]
            if show_raw:
                wl_r_raw, qe_r_raw = data[:, 0], data[:, 1]
                wl_g_raw, qe_g_raw = data[:, 2], data[:, 3]
                wl_b_raw, qe_b_raw = data[:, 4], data[:, 5]
        else:
            raise ValueError("csv_file required when calling as static method")

        fig, ax = plt.subplots(figsize=(10, 6))
        ax.plot(wl, qe_r, "r-", label="Red", linewidth=2)
        ax.plot(wl, qe_g, "g-", label="Green", linewidth=2)
        ax.plot(wl, qe_b, "b-", label="Blue", linewidth=2)

        if show_raw:
            mask_r = (wl_r_raw != -1) & (qe_r_raw != -1)
            mask_g = (wl_g_raw != -1) & (qe_g_raw != -1)
            mask_b = (wl_b_raw != -1) & (qe_b_raw != -1)
            ax.plot(wl_r_raw[mask_r], qe_r_raw[mask_r], "ro", markersize=4, alpha=0.5)
            ax.plot(wl_g_raw[mask_g], qe_g_raw[mask_g], "go", markersize=4, alpha=0.5)
            ax.plot(wl_b_raw[mask_b], qe_b_raw[mask_b], "bo", markersize=4, alpha=0.5)

        ax.set_xlabel("Wavelength [nm]")
        ax.set_ylabel("Absolute QE")
        ax.legend()
        ax.grid(True, alpha=0.3)
        plt.tight_layout()
        plt.show()


# Usage example
if __name__ == "__main__":

    # Settings
    name = "CIS2521"
    filename = name + ".png"
    path = Path(__file__).parent
    filepath = path / "sensors" / filename
    xmin = 400
    xmax = 1100
    ymin = 0
    ymax = 0.6
    x_spacing = 100
    y_spacing = 0.1

    # Initialize
    qe = QEinterpolator(name, filepath, xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax)

    # Click points interactively - R -> G -> B
    wl_r, qe_r = qe.click_points(x_spacing=x_spacing, y_spacing=y_spacing, color="RED")
    wl_g, qe_g = qe.click_points(x_spacing=x_spacing, y_spacing=y_spacing, color="GREEN")
    wl_b, qe_b = qe.click_points(x_spacing=x_spacing, y_spacing=y_spacing, color="BLUE")
    # Set raw data
    qe.set_raw_data(wl_r, qe_r, wl_g, qe_g, wl_b, qe_b)

    # Interpolate and save
    qe.interpolate(wl_start=xmin, wl_end=xmax, spacing=2.5)
    qe.save_csv()

    # Plot from memory or CSV
    qe.plot("QE_" + name + ".csv")

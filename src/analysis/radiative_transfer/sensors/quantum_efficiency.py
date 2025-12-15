import csv
from pathlib import Path


class QE:
    def __init__(self):

        self.path = Path(__file__).parent

    def __read_csv(self, name):
        wl_r_RAW = []
        qe_r_RAW = []
        wl_g_RAW = []
        qe_g_RAW = []
        wl_b_RAW = []
        qe_b_RAW = []
        wl = []
        qe_r = []
        qe_g = []
        qe_b = []

        file_path = self.path / name

        with open(file_path, newline="") as f:
            reader = csv.DictReader(f)
            for row in reader:
                wl_r_RAW.append(float(row["wl_r_RAW"]))
                qe_r_RAW.append(float(row["qe_r_RAW"]))
                wl_g_RAW.append(float(row["wl_g_RAW"]))
                qe_g_RAW.append(float(row["qe_g_RAW"]))
                wl_b_RAW.append(float(row["wl_b_RAW"]))
                qe_b_RAW.append(float(row["qe_b_RAW"]))
                wl.append(float(row["wl"]))
                qe_r.append(float(row["qe_r"]))
                qe_g.append(float(row["qe_g"]))
                qe_b.append(float(row["qe_b"]))

        return (
            wl_r_RAW,
            qe_r_RAW,
            wl_g_RAW,
            qe_g_RAW,
            wl_b_RAW,
            qe_b_RAW,
            wl,
            qe_r,
            qe_g,
            qe_b,
        )

    def CMV12000(self):

        (
            self.red_wl_RAW,
            self.red_RAW,
            self.green_wl_RAW,
            self.green_RAW,
            self.blue_wl_RAW,
            self.blue_RAW,
            self.wl,
            self.red,
            self.green,
            self.blue,
        ) = self.__read_csv("QE_CMV12000.csv")

        self.wl_min = min(self.wl)
        self.wl_max = max(self.wl)

    def IMX249(self):

        (
            self.red_wl_RAW,
            self.red_RAW,
            self.green_wl_RAW,
            self.green_RAW,
            self.blue_wl_RAW,
            self.blue_RAW,
            self.wl,
            self.red,
            self.green,
            self.blue,
        ) = self.__read_csv("QE_IMX249.csv")

        self.wl_min = min(self.wl)
        self.wl_max = max(self.wl)

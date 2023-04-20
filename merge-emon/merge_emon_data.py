#!/usr/bin/python3

# merge one specific core's emon from core_view summary emon file
import pandas as pd
import re
import argparse
import os


class CsvFile:
    def __init__(self, filename):
        self.filename = filename
        self.df = None

    def read(self):
        self.df = pd.read_csv(self.filename)

    def write(self, df):
        df.to_csv(self.filename, sep=',', encoding='utf-8', index=False)


class EmonData(CsvFile):
    def __init__(self, filename):
        CsvFile.__init__(self, filename)
        self.read()
        self.colnames = ["ITEMS", "VALUES"]

    # Parse the column names to find TPS.
    def find_tps(self):
        for col in self.df.columns:
            x = re.search(r"(TPS)(=)(\d+\.*\d*)", col)
            if (x != None):
                return [x.group(1), float(x.group(3))]

    def find_core(self, col_name):
        if col_name in self.df.columns:
            count_data = pd.concat([count_data, self.df[col_name]], axis=1)

    # Update the column names because the original column names don't make sense.
    def set_col_name(self):
        self.df.set_axis(self.colnames, axis=1, copy=True)

    def reformat_data(self):
        tps = self.find_tps()
        self.set_col_name()

        new_row = pd.DataFrame(
            {self.colnames[0]: tps[0], self.colnames[1]: tps[1]}, index=[0])
        self.df = pd.concat([new_row, self.df[:]]).reset_index(drop=True)
        return self.df

    def merge_core_data(self):
        core = self.find_core()
        self.set_col_name()

        new_row = pd.DataFrame(
            {self.colnames[0]: core[0], self.colnames[1]: core[1]}, index=[0])
        self.df = pd.concat([new_row, self.df[:]]).reset_index(drop=True)
        return self.df


def merge_tps(output):
    # Output file.
    outfile = CsvFile(output)
    csvfiles = []
    # All .csv files.
    for path in args.inputs:
        # If if is a directory, find all .csv files in it.
        if os.path.isdir(path):
            for filename in os.listdir(path):
                if filename.endswith(".csv"):
                    csvfiles.append(os.path.join(path, filename))
        else:
            csvfiles.append(path)

    setfirstcol = False
    alldata = []
    # Read data from all emon .csv file
    for filename in csvfiles:
        emon = EmonData(filename)
        data = emon.reformat_data()

        if setfirstcol is False:
            alldata.append(data[["ITEMS"]])
            setfirstcol = True

        alldata.append(data[["VALUES"]])

    if alldata:
        md = pd.concat(alldata, axis=1)

        # Calculate the average
        if int(args.calculate_average) != 0:
            # Exclude the first columnt.
            columnssize = len(md.columns) - 1

            if columnssize % int(args.calculate_average) != 0:
                groupsize = int(columnssize / int(args.calculate_average)) + 1
            else:
                groupsize = int(columnssize / int(args.calculate_average))

            for i in range(groupsize):
                startpos = 1 + i * int(args.calculate_average)
                endpos = 1 + (i + 1) * int(args.calculate_average)
                if endpos >= columnssize + 1:
                    endpos = columnssize + 1

                colname = "mean" + "(" + str(startpos) + \
                    "-" + str(endpos - 1) + ")"
                md[colname] = md.iloc[:, startpos:endpos].mean(axis=1)

        print(md)

        # Write the combined data into the new .csv file.
        outfile.write(md)

        # Write the conbimed data into a .xlsx file.
        xlsxname = re.sub(".csv", ".xlsx", args.output)
        sheetname = re.sub(".csv", "", args.output)

        md.to_excel(xlsxname, sheet_name="Benchmark Data", index=False)
    print("*****The combined data has been written to %s and %s*******" %
          (args.output, xlsxname))


def merge_core_data(output, socket, core):
    # Output file.
    outfile = CsvFile(output)
    outfile.df = pd.DataFrame()
    csvfiles = []
    core_col_name = "socket " + str(socket) + " core " + str(core)
    # All .csv files.
    for path in args.inputs:
        # If if is a directory, find all .csv files in it.
        if os.path.isdir(path):
            for filename in os.listdir(path):
                if filename.endswith(".csv"):
                    csvfiles.append(os.path.join(path, filename))
        else:
            csvfiles.append(path)

    setfirstcol = False
    alldata = []
    # Read data from all emon .csv file
    for filename in csvfiles:
        emon = EmonData(filename)
        data = emon.reformat_data()

        if setfirstcol is False:
            alldata.append(data[["ITEMS"]])
            setfirstcol = True

        alldata.append(data[["VALUES"]])

    if alldata:
        md = pd.concat(alldata, axis=1)

        # Calculate the average
        if int(args.calculate_average) != 0:
            # Exclude the first columnt.
            columnssize = len(md.columns) - 1

            if columnssize % int(args.calculate_average) != 0:
                groupsize = int(columnssize / int(args.calculate_average)) + 1
            else:
                groupsize = int(columnssize / int(args.calculate_average))

            for i in range(groupsize):
                startpos = 1 + i * int(args.calculate_average)
                endpos = 1 + (i + 1) * int(args.calculate_average)
                if endpos >= columnssize + 1:
                    endpos = columnssize + 1

                colname = "mean" + "(" + str(startpos) + \
                    "-" + str(endpos - 1) + ")"
                md[colname] = md.iloc[:, startpos:endpos].mean(axis=1)

        print(md)

        # Write the combined data into the new .csv file.
        outfile.write(md)

        # Write the conbimed data into a .xlsx file.
        xlsxname = re.sub(".csv", ".xlsx", args.output)
        sheetname = re.sub(".csv", "", args.output)

        md.to_excel(xlsxname, sheet_name="Benchmark Data", index=False)

    print("*****The combined data has been written to %s and %s*******" %
          (args.output, xlsxname))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='An utilty to combine Emon .csv files.')
    parser.add_argument('inputs', metavar='input', nargs='+',
                        help='An input .csv file or a directory.')
    parser.add_argument("-o", "--output", help="Output file",
                        default="merged_emon.csv")
    parser.add_argument("-m", "--calculate_average",
                        help="Calculate the average of the rows", default=0)
    parser.add_argument("-t", "--merge_tps",
                        help="merge tps data", default=False)
    parser.add_argument("-e", "--merge_core_data",
                        help="merge target core data", default=False)
    parser.add_argument("-s", "--socket",
                        help="socket number", default=0)
    parser.add_argument("-c", "--core",
                        help="core number", default=0)

    args = parser.parse_args()

    if args.merge_tps:
        merge_tps(args.output)

    if args.merge_core_data:
        merge_core_data(args.output, args.socket, args.core)

# python3 merge_emon_data.py -o merged_emon.csv -m 3 pyperf-loop-result/pidigits/emon-1/__edp_core_view_summary.per_txn.csv pyperf-loop-result/pidigits/emon-2/__edp_core_view_summary.per_txn.csv pyperf-loop-result/pidigits/emon-3/__edp_core_view_summary.per_txn.csv
# python3 merge_emon_data.py -o merged_emon.csv 1.csv 2.csv 3.csv

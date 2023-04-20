import argparse
import pandas as pd

# Merge target core data from each gived core_summary.csv to a csv file, and caculate mean value


def merge_col_data(inputs, output, col_name):
    data = pd.DataFrame()
    print("Target colume name is ", col_name)
    # Copy the first column of the first CSV to data[ITEMS]
    df = pd.read_csv(inputs[0], encoding='utf-8', on_bad_lines='skip')
    data['ITEMS'] = df.iloc[:, 0]
    # Copy colume named col_name of each CSV to data[VALUES-i]
    for i in range(len(inputs)):
        print("Processing file: ", inputs[i])
        df = pd.read_csv(inputs[i], encoding='utf-8', on_bad_lines='skip')
        if col_name in df.columns:
            # check data type of df[col_name]
            data['VALUES-' + str(i)] = df[col_name]

    # Caculate mean and add to data['Mean'], data type is float64
    print("Caculating mean value...")
    data['Mean'] = data.iloc[:, 1:].mean(axis=1)
    # Save data to csv file
    data.to_csv(output, index=False)
    print("Result was saved to file: ", output)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='An utilty to combine Emon .csv files.')
    parser.add_argument('inputs', metavar='input', nargs='+',
                        help='An input .csv file or a directory.')
    parser.add_argument("-o", "--output", help="Output file",
                        default="merged_emon_core.csv")
    parser.add_argument("-m", "--merge_core_data",
                        help="merge target core data", default=True)
    parser.add_argument("-s", "--socket",
                        help="target core id", default=0)
    parser.add_argument("-c", "--core",
                        help="target core id", default=0)

    args = parser.parse_args()

    if args.merge_core_data:
        col_name = 'socket ' + str(args.socket) + ' core ' + str(args.core)
        merge_col_data(args.inputs, args.output, col_name)

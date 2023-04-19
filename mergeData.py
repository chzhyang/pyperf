import argparse
import pandas as pd


def merge_core_data(inputs, output, socket, core):
    data = pd.DataFrame()
    # core_col = 'socket ' + str(socket) + ' core ' + str(core)
    core_col = "socket 0 core 3"
    print(core_col)
    # 读取第一个csv文件，获取index列
    print(str(inputs[0]))
    df = pd.read_csv(inputs[0], encoding='utf-8')
    # data中增加列，列名ITEMS，，并将df的第一列复制到ITEMS
    data['ITEMS'] = df.iloc[:, 0]
    # 逐个读取每个csv文件，并将core列的数据复制到data中, core列名为VALUES-i
    for i in range(len(inputs)):
        print(str(inputs[i]))
        df = pd.read_csv(inputs[i])
        if core_col in df.columns:
            data['VALUES-' + str(i)] = df[core_col]

    # 计算平均值
    data['mean'] = data.mean(axis=1)

    data.to_csv(output, index=False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='An utilty to combine Emon .csv files.')
    parser.add_argument('inputs', metavar='input', nargs='+',
                        help='An input .csv file or a directory.')
    parser.add_argument("-o", "--output", help="Output file",
                        default="merged_emon.csv")
    parser.add_argument("-e", "--merge_core_data",
                        help="merge target core data", default=False)
    parser.add_argument("-s", "--socket",
                        help="socket number", default=0)
    parser.add_argument("-c", "--core",
                        help="core number", default=0)

    args = parser.parse_args()

    if args.merge_core_data:
        merge_core_data(args.inputs, args.output, args.socket, args.core)

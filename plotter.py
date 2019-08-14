# coding: utf-8

import matplotlib.pyplot as plt
import csv
import argparse


def read_timeprofiles(path):
    queries = [None]

    with open(path, 'r') as f:
        rows = csv.reader(f, delimiter=',')
        next(rows, None)       # skip the header
        data = {"y": [], "xmin": [], "xmax": []}
        current_query = None
        for row in rows:
            query, xmin, xmax, y = [int(i) for i in row]
            if current_query is not None and current_query != query:
                queries.append(data)
                data = {"y": [], "xmin": [], "xmax": []}
            current_query = query
            data["y"].append(y)
            data["xmin"].append(xmin)
            data["xmax"].append(xmax)
        queries.append(data)

    return queries


def read_queries(path):
    ranks = [None, [], [], [], [], [], [], [], [], [], [], [], [], [], []]
    queries = [None]
    with open(path, 'r') as f:
        rows = csv.reader(f, delimiter=',')
        next(rows, None)  # skip the header
        n = 1
        for row in rows:
            log2rank = int(row[3])
            query = {
                "n": n,
                "source": row[0],
                "destination": row[1],
                "departure_time": int(row[2]),
                "log2_of_station_rank": log2rank,
                # "station_rank": int(row[4]),
                # "walk_time": int(row[5])
            }
            ranks[log2rank].append(query)
            queries.append(query)
            n += 1

    return ranks, queries


def delay(dynamic, static):
    dyni, stati = 0, 0
    delay = abs(dynamic['y'][dyni] - static['y'][stati])
    delay_min, delay_max = delay, delay
    while dyni < len(dynamic['y']) and stati < len(static['y']):
        delay = abs(dynamic['y'][dyni] - static['y'][stati])
        delay_min = min(delay_min, delay)
        delay_max = max(delay_max, delay)
        if dynamic['xmax'][dyni] < static['xmax'][stati]:
            dyni += 1
        elif dynamic['xmax'][dyni] > static['xmax'][stati]:
            stati += 1
        else:
            dyni += 1
            stati += 1
    return {"min": delay_min, "max": delay_max}


def plot_query(q, dyng, ming, maxg, avgg, show):
    tpdyn, tpmin, tpmax, tpavg = dyng[q], ming[q], maxg[q], avgg[q]
    plt.hlines('y', 'xmin', 'xmax', data=tpdyn, label='dynamic')
    plt.hlines('y', 'xmin', 'xmax', data=tpmin, color='r', label='minimum')
    plt.hlines('y', 'xmin', 'xmax', data=tpmax, color='g', label='maximum')
    plt.hlines('y', 'xmin', 'xmax', data=tpavg, color='b', label='average')
    plt.ylabel('arrival time')
    plt.xlabel('departure time')

    delay_gmin = delay(tpdyn, tpmin)
    delay_gmax = delay(tpdyn, tpmax)
    delay_gavg = delay(tpdyn, tpavg)
    plt.title("Query #{} delay min:({}, {}) max: ({}, {}) avg: ({}, {})"
              .format(q,
                      delay_gmin['min'], delay_gmin['max'],
                      delay_gmax['min'], delay_gmax['max'],
                      delay_gavg['min'], delay_gavg['max']))
    if show:
        plt.show()
    else:
        plt.savefig("plots/{}.svg".format(q))
    plt.clf()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("dynamic")
    parser.add_argument("static_min")
    parser.add_argument("static_max")
    parser.add_argument("static_avg")
    parser.add_argument("queries")
    parser.add_argument("-q", help="plot a specific query", type=int)
    parser.add_argument("-show", help="show the plots")
    args = parser.parse_args()

    print("Loading raptor time profiles…")
    dynamic = read_timeprofiles(args.dynamic)
    print("Loading static graph time profiles…")
    static_min = read_timeprofiles(args.static_min)
    static_max = read_timeprofiles(args.static_max)
    static_avg = read_timeprofiles(args.static_avg)
    print("Loading queries…")
    ranks, _ = read_queries(args.queries)

    if args.q:
        plot_query(args.q, dynamic, static_min, static_max, static_avg,
                   args.show)
    else:
        for rank in range(1, 15):
            for i in range(5):  # print the first 5 queries of each rank
                query = ranks[rank][i]['n']
                print("Query #{}".format(query))
                plot_query(query, dynamic, static_min, static_max, static_avg,
                           args.show)


if __name__ == '__main__':
    main()
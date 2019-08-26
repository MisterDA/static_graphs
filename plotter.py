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
    return (delay_min, delay_max)


def plot_query(q, dyng, ming, maxg, avgg, show, delays, delaysf):
    tpdyn, tpmin, tpmax, tpavg = dyng[q], ming[q], maxg[q], avgg[q]

    plt.figure()
    fig, axs = plt.subplots(nrows=1, ncols=3, sharex=True, sharey=True)

    for i in range(3):
        axs[i].hlines('y', 'xmin', 'xmax', data=tpdyn, label='dynamique',
                      color='black', alpha=0.6)
    axs[0].set_title("minimum")
    axs[0].hlines('y', 'xmin', 'xmax', data=tpmin, label='minimum',
               color='green', alpha=0.8)
    axs[1].set_title("maximum")
    axs[1].hlines('y', 'xmin', 'xmax', data=tpmax, label='maximum',
               color='red', alpha=0.7)
    axs[2].set_title("moyen")
    axs[2].hlines('y', 'xmin', 'xmax', data=tpavg, label='moyen',
               color='blue', alpha=0.6)
    #plt.legend(loc='lower right')
    plt.ylabel("Temps d'arrivée (s)")
    plt.xlabel("Temps de départ (s)")

    if show:
        plt.show()
    else:
        # plt.savefig("plots/{}.svg".format(q), format='svg')
        # plt.savefig("plots/{}.eps".format(q), format='eps', dpi=600)
        plt.savefig("plots/{}.pdf".format(q), format='pdf')
    plt.clf()

    if delays is not None:
        minmin, minmax = delay(tpdyn, tpmin)
        delays["min"]['min'].append(minmin)
        delays["min"]['max'].append(minmax)
        maxmin, maxmax = delay(tpdyn, tpmax)
        delays["max"]['min'].append(maxmin)
        delays["max"]['max'].append(maxmax)
        avgmin, avgmax = delay(tpdyn, tpavg)
        delays["avg"]['min'].append(avgmin)
        delays["avg"]['max'].append(avgmax)
        delaysf.write("{},{},{},{},{},{},{}\n"
                      .format(q, minmin, minmax, maxmin, maxmax, avgmin, avgmax))


def plot_delays(delays):
    plt.figure()
    plt.plot(delays['min']['min'], '+')
    plt.plot(delays['min']['max'], 'x')
    plt.savefig("plots/delays_min.pdf", format='pdf')
    plt.clf()
    plt.figure()
    plt.plot(delays['max']['min'], "+")
    plt.plot(delays['max']['max'], "x")
    plt.savefig("plots/delays_max.pdf", format='pdf')
    plt.clf()
    plt.figure()
    plt.plot(delays['avg']['min'], "+")
    plt.plot(delays['avg']['max'], "x")
    plt.savefig("plots/delays_avg.pdf", format='pdf')
    plt.clf()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("dynamic")
    parser.add_argument("static_min")
    parser.add_argument("static_max")
    parser.add_argument("static_avg")
    parser.add_argument("queries")
    parser.add_argument("-q", help="plot a specific query", type=int)
    parser.add_argument("-delays", help="delays")
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

    plt.rc('text', usetex=True)
    plt.rc('font', family='serif')

    delaysf = None
    delays = None
    if args.delays:
        delaysf = open(args.delays, "w+")
        delaysf.write("query,minmin,minmax,maxmin,maxmax,avgmin,avgmax\n")
        delays = {
            "min": {"min": [], "max": []},
            "max": {"min": [], "max": []},
            "avg": {"min": [], "max": []},
        }

    if args.q:
        plot_query(args.q, dynamic, static_min, static_max, static_avg,
                   args.show, delays, delaysf)
    else:
        for rank in range(1, 15):
            for i in range(min(5,len(ranks[rank]))):  # print the first 5 queries of each rank
                query = ranks[rank][i]['n']
                print("Query #{}".format(query))
                plot_query(query, dynamic, static_min, static_max, static_avg,
                           args.show, delays, delaysf)


    if delays is not None:
        plot_delays(delays)
        delaysf.close()


if __name__ == '__main__':
    main()

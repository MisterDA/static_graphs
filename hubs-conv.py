import csv
import sys

def main():
    hin = open('walk_and_transfer_inhubs.gr', 'w+')
    hout = open('walk_and_transfer_outhubs.gr', 'w+')

    for line in sys.stdin:
        words = line.split()
        words.pop(2)
        if words[0] == 'o':
            words[0] = 'a'
            hout.write(' '.join(words))
            hout.write("\n")
        elif words[0] == 'i':
            words[0] = 'a'
            hin.write(' '.join(words))
            hin.write("\n")

if __name__ == '__main__':
    main()

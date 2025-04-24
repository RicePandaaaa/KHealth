#include <stdlib.h>
#include <time.h>

double score(double * input) {
    srand(time(NULL));

    double min = 60;
    double max = 220;


    if (min > max) {
        double temp = min; min = max; max = temp;
    }
    double scale = (double)rand() / RAND_MAX;
    return min + scale * (max - min);
}

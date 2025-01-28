from math import pi

F = 120
D_w = 0.15
C = 9

def K(C):
    return (4 * C - 1) / (4 * C - 4) + (0.615 / C)

tau = 8 * K(C) * F * C / (pi * D_w ** 2)

print(tau)

while tau > 280000:
    C += 1
    tau = 8 * K(C) * F * C / (pi * D_w ** 2)
    print(tau)
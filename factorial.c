/*
 * SPDX-FileCopyrightText: © 2022 James Reynolds
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

static int factorial(int x){
    if(x == 0) return 1;
    return x * factorial(x - 1);
}

int main(){
    volatile int x = 6;
    return factorial(x);
}

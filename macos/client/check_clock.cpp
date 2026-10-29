#include "stdpch.h"
#include "time_task.h"
#include <chrono>
#include <thread>
#include <iostream>

int main()
{
    NLMISC::CApplicationContext context;
    CTimeTask clock;
    clock.init();
    clock.update();
    if (clock.deltaTime() != 0.0) return 1;
    const double start = clock.time();
    std::this_thread::sleep_for(std::chrono::milliseconds(150));
    clock.update();
    const double elapsed = clock.time() - start;
    std::cout << "150 ms wait: game clock advanced " << elapsed << " seconds\n";
    if (elapsed < 0.10 || elapsed > 1.0) return 2;
    if (std::abs(clock.deltaTime() - elapsed) > 0.001) return 3;
    clock.reset();
    clock.update();
    if (clock.deltaTime() != 0.0) return 4;
    return 0;
}

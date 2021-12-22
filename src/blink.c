// taken from
// https://learn.circuit.rocks/how-to-control-the-raspberry-pi-gpio-using-c

#include <wiringPi.h>

const int i, leds[4] = {2,14,17,23};

void blink (const int led)
{
    digitalWrite(led, HIGH);
    delay(1000);
    digitalWrite(led, LOW);
    delay(1000);
}

int main(void)
{
    wiringPiSetupGpio();
    for (int i; i<sizeof(leds); i++)
    {
        pinMode(leds[i],OUTPUT);
        delay(10); 
    }
    while(1)
    {
	for (int j = 0; j < 4; j++)
	{
	    blink(leds[j]);
	}
    }
    return 0;
}
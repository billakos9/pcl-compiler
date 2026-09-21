#include <ctype.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef int64_t pcl_integer;
typedef uint8_t pcl_boolean;

void writeInteger(pcl_integer value)
{
    printf("%lld", (long long)value);
    fflush(stdout);
}

void writeBoolean(pcl_boolean value)
{
    fputs(value ? "true" : "false", stdout);
    fflush(stdout);
}

void writeChar(char value)
{
    putchar((unsigned char)value);
    fflush(stdout);
}

void writeReal(double value)
{
    char buffer[64];
    snprintf(buffer, sizeof(buffer), "%.6g", value);
    fputs(buffer, stdout);

    if (isfinite(value) && strpbrk(buffer, ".eE") == NULL)
        fputs(".0", stdout);

    fflush(stdout);
}

void writeString(const char *value)
{
    fputs(value, stdout);
    fflush(stdout);
}

static int read_non_whitespace(void)
{
    int character;

    do {
        character = getchar();
    } while (character != EOF && isspace((unsigned char)character));

    return character;
}

pcl_integer readInteger(void)
{
    pcl_integer value = 0;
    int sign = 1;
    int character = read_non_whitespace();

    if (character == '-') {
        sign = -1;
        character = getchar();
    }

    while (character >= '0' && character <= '9') {
        value = value * 10 + (character - '0');
        character = getchar();
    }

    return sign * value;
}

pcl_boolean readBoolean(void)
{
    char buffer[6];
    size_t length = 0;
    int character = read_non_whitespace();

    while (character != EOF && !isspace((unsigned char)character)) {
        if (length + 1 < sizeof(buffer))
            buffer[length++] = (char)character;
        character = getchar();
    }

    buffer[length] = '\0';
    return strcmp(buffer, "true") == 0;
}

char readChar(void)
{
    int character = getchar();
    return character == EOF ? '\0' : (char)character;
}

double readReal(void)
{
    double value = 0.0;

    if (scanf("%lf", &value) == 1)
        (void)getchar();

    return value;
}

void readString(pcl_integer size, char *destination)
{
    pcl_integer index = 0;

    if (size <= 0)
        return;

    while (index < size - 1) {
        int character = getchar();

        if (character == EOF || character == '\n')
            break;

        destination[index++] = (char)character;
    }

    destination[index] = '\0';
}

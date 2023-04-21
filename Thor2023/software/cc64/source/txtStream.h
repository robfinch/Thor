#pragma once
#include <string.h>
#include <iostream>
#include <fstream>
#include <iomanip>

class txtoStream : public std::ofstream
{
	char buf[5000];
public:
	int level;
	std::string name;
public:
//  txtoStream(std::streambuf* buf, bool addit=false) : std::ostream(buf, addit) {};
  txtoStream() : std::ofstream() {};
	void write(char *buf) { if (level) {
		if (buf)
	   std::ostream::write(buf, strlen(buf));
       flush(); }};
	void write(const char* buf) {
		write((char*)buf);
	};
	void printf(char *str) { if (level && str != nullptr) write(str); };
	void printf(const char *str) { if (level && str != nullptr) write((char *)str); };
	void printf(char *fmt, char *str);
	void printf(const char* fmt, char* str) {
		printf((char*)fmt, str);
	};
	void printf(char *fmt, char *str, int n);
	void printf(char *fmt, char *str, char *str2);
	void printf(char *fmt, char *str, char *str2, int n);
	void printf(char *fmt, int n, char *str);
	void printf(char *fmt, int n);
	void printf(const char* fmt, int n) {
		printf((char*)fmt, n);
	};
	void printf(char *fmt, int n, int m);
	void printf(char *fmt, __int64 n);
	void putch(char ch) { 
	    if (level) {
	     buf[0] = ch;
	     buf[1] = '\0';
	     buf[2] = '\0';
	     buf[3] = '\0';
       std::ofstream::write(buf, 1);
       }};
	void puts(const char *);
	void writeAsHex(const void *, int);
};

// Make it easy to disable debugging output
// Mirror the txtoStream class with one that does nothing.

class txtoStreamNull
{
public:
  int level;
  void open(...);
  void close();
  void write(char *) { };
  void printf(...) { };
  void putch(char) { };
  void puts(const char *) {} ;
};

class txtiStream : public std::ifstream
{
public:
	void readAsHex(const void *, int);
};

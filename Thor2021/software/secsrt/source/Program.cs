using System;

namespace secsrt
{
	class Program
	{
		String filetext;
		String[] lines;
		Char[] cha;
		String[] textout;
		String[] bssout;
		String[] dataout;
		String[] rodataout;
		String[] lcommout;
		String[] otherout;
		String[] linesout;
		int textndx, datandx, rodatandx, otherndx, lcommndx, bssndx;

		void init()
		{
			cha = new char[1];
			cha[0] = '\x0a';
		}
		private void sort()
		{
			bool intext = true;
			bool indata = false;
			bool inrodata = false;
			bool inlcomm = false;
			bool inbss = false;
			textndx = 0;
			datandx = 0;
			rodatandx = 0;
			lcommndx = 0;
			bssndx = 0;
			otherndx = 0;

			foreach (string ln in lines)
			{
				if (ln.Length < 2)
					continue;
				if (ln.Contains((char)0x26))
					continue;
				if (ln.Contains(".text"))
				{
					intext = true;
					indata = false;
					inrodata = false;
					inlcomm = false;
					inbss = false;
				}
				else if (ln.Contains(".data"))
				{
					intext = false;
					indata = true;
					inrodata = false;
					inlcomm = false;
					inbss = false;
				}
				else if (ln.Contains(".rodata"))
				{
					intext = false;
					indata = false;
					inlcomm = false;
					inrodata = true;
					inbss = false;
				}
				else if (ln.Contains(".lcomm"))
				{
					intext = false;
					indata = false;
					inlcomm = true;
					inrodata = false;
					inbss = false;
					lcommout[lcommndx] = ln;
					lcommndx++;
				}
				else if (ln.Contains(".bss"))
				{
					intext = false;
					indata = false;
					inlcomm = false;
					inrodata = false;
					inbss = true;
				}
				else
				{
					if (intext)
					{
						textout[textndx] = ln;
						textndx++;
					}
					else if (indata)
					{
						dataout[datandx] = ln;
						datandx++;
					}
					else if (inrodata)
					{
						rodataout[rodatandx] = ln;
						rodatandx++;
					}
					else if (inlcomm)
					{
						lcommout[lcommndx] = ln;
						lcommndx++;
					}
					else if (inbss)
					{
						bssout[bssndx] = ln;
						bssndx++;
					}
					else
					{
						otherout[otherndx] = ln;
						otherndx++;
					}
				}
			}
			Array.Resize(ref textout, textndx);
			Array.Resize(ref dataout, datandx);
			Array.Resize(ref rodataout, rodatandx);
			Array.Resize(ref lcommout, lcommndx);
			Array.Resize(ref bssout, bssndx);
		}

		void run(String name)
		{
			System.IO.TextReader trdr = new System.IO.StreamReader(name);
			System.IO.TextWriter twtr;
			filetext = trdr.ReadToEnd();
			trdr.Close();
			lines = filetext.Split(cha);
			textout = new string[lines.Length];
			dataout = new string[lines.Length];
			rodataout = new string[lines.Length];
			lcommout = new string[lines.Length];
			bssout = new string[lines.Length];
			sort();
			twtr = new System.IO.StreamWriter("secsorted.asm");
//			twtr.WriteLine("\t.org\t0x00000");
			twtr.WriteLine("\t.text");
			foreach (String ln in textout) {
				twtr.WriteLine(ln);
			}
			twtr.WriteLine("\t.rodata");
			twtr.WriteLine("\t.p2align\t12");
			//twtr.WriteLine("\t.org _end_text + 0x1000");
			//twtr.WriteLine("\t.align 0x1000");
			foreach (String ln in rodataout)
			{
				twtr.WriteLine(ln);
			}
			twtr.WriteLine("\t.data");
			twtr.WriteLine("\t.p2align\t12");
			//twtr.WriteLine("\t.org _end_rodata + 0x1000");
			//twtr.WriteLine("\t.align 0x1000");
			foreach (String ln in dataout)
			{
				twtr.WriteLine(ln);
			}
			twtr.WriteLine("\t.bss");
			twtr.WriteLine("\t.p2align\t12");
			foreach (String ln in bssout)
			{
				twtr.WriteLine(ln);
			}
			foreach (String ln in lcommout)
			{
				twtr.WriteLine(ln);
			}
			twtr.Close();
		}

		static void Main(string[] args)
		{
			Program prg = new Program();
			prg.init();
			if (args.Length < 1)
			{
				Console.WriteLine("secsrt <filename>");
				Console.WriteLine("  Sorts and groups the sections in a file.");
			}
			else
			{
				prg.run(args[0]);
			}
		}
	}
}

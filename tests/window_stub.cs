// Stand-ins for the Windows Forms and System.Drawing types the RADE window uses, so tests/engine_test.sh (section "window") can run the
// window's logic on Linux (PowerShell 7 has no Windows Forms there). Nothing is drawn: a control keeps its values, an
// event keeps its handlers, and the test "user" (tests/window_driver.ps1) fires them. A member that is not declared
// here is taken as given (Dyn), so a layout, style or paint member with a wrong name is NOT found by the test; a wrong
// variable, key or function name in logic the test reaches is.
using System;
using System.Collections;
using System.Collections.Generic;
using System.Dynamic;
using System.Management.Automation;

namespace RadeStub {
  public class Dyn : DynamicObject {
    public Dictionary<string, object> Values = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
    public Dictionary<string, List<ScriptBlock>> Events = new Dictionary<string, List<ScriptBlock>>(StringComparer.OrdinalIgnoreCase);
    public override bool TryGetMember(GetMemberBinder b, out object r) { if (!Values.TryGetValue(b.Name, out r)) { r = new Dyn(); Values[b.Name] = r; } return true; }
    public override bool TrySetMember(SetMemberBinder b, object v) { Values[b.Name] = v; return true; }
    public override bool TryInvokeMember(InvokeMemberBinder b, object[] a, out object r) {
      r = System.Management.Automation.Internal.AutomationNull.Value;   // as a void method: nothing goes to the pipeline
      if (b.Name.StartsWith("Add_", StringComparison.OrdinalIgnoreCase) && a.Length == 1) {
        object h = a[0]; if (h is PSObject) h = ((PSObject)h).BaseObject;
        string n = b.Name.Substring(4); if (!Events.ContainsKey(n)) Events[n] = new List<ScriptBlock>();
        Events[n].Add((ScriptBlock)h);
      }
      return true;   // any other method does nothing
    }
    public void Fire(string name, object args) {
      List<ScriptBlock> hs; if (!Events.TryGetValue(name, out hs)) return;
      foreach (ScriptBlock h in hs.ToArray()) h.InvokeWithContext(null, new List<PSVariable> { new PSVariable("this", this), new PSVariable("_", args) });
    }
    public bool Has(string name) { return Values.ContainsKey(name) && Values[name] != null && !(Values[name] is Dyn); }
  }
  public static class Driver {
    public static ScriptBlock Pump; public static System.Windows.Forms.Control Focus; public static string Clip = "";
    public static List<System.Windows.Forms.Timer> Timers = new List<System.Windows.Forms.Timer>();
    public static int Pumps = 0;
    public static System.Windows.Forms.Screen[] Screens() { return new System.Windows.Forms.Screen[] { new System.Windows.Forms.Screen() }; }
    public static float FormDpi = 96f;   // the dpi the form scales to (RADE_T_SCALE=150: 144); the screen dpi (Graphics.DpiX) stays 96
    public static bool RunThrows = false; public static string ShownBy = "";   // RunThrows: Application.Run fails as when a message loop already runs
  }
}
// PowerShell 7 on Linux has System.Drawing.Common, whose Font, Pen and the like throw there: the test copy of the bundle
// names these RadeDraw.* instead (tests/engine_test.sh). Size, Point, Rectangle and Color are the real types.
namespace RadeDraw {
  using System.Drawing;
  [Flags] public enum FontStyle { Regular = 0, Bold = 1, Italic = 2, Underline = 4 }
  public class Font : RadeStub.Dyn { public string Name; public float SizeInPoints; public FontStyle Style;
    public Font(string f, float s) { Name = f; SizeInPoints = s; } public Font(string f, float s, FontStyle st) { Name = f; SizeInPoints = s; Style = st; }
    public int Height { get { return (int)Math.Round(SizeInPoints * 1.7); } } }
  public class Pen : RadeStub.Dyn { public Pen(Color c) { } public Pen(Color c, float w) { } public void Dispose() { } }
  public class SolidBrush : RadeStub.Dyn { public SolidBrush(Color c) { } public void Dispose() { } }
  public class Image : RadeStub.Dyn { public static Image FromStream(System.IO.Stream s) { return new Image(); } }
  public class Graphics : RadeStub.Dyn { public float DpiX = 96f; public static Graphics FromHwnd(IntPtr h) { return new Graphics(); } public void Dispose() { } }
}
namespace System.Windows.Forms {
  using System.Drawing; using RadeDraw;
  [Flags] public enum TextFormatFlags { Left = 0, Top = 0, HorizontalCenter = 1, Right = 2, VerticalCenter = 4, SingleLine = 32, WordBreak = 16, NoPrefix = 2048, TextBoxControl = 8192, EndEllipsis = 32768 }
  public enum MessageBoxButtons { OK, YesNo } public enum MessageBoxIcon { None, Warning } public enum MessageBoxDefaultButton { Button1, Button2 }
  public struct Padding { public int Left, Top, Right, Bottom; public Padding(int l, int t, int r, int b) { Left = l; Top = t; Right = r; Bottom = b; } public Padding(int a) { Left = Top = Right = Bottom = a; } }
  public class ColumnStyle { public ColumnStyle(object a) { } public ColumnStyle(object a, object b) { } }
  public class RowStyle { public RowStyle(object a) { } public RowStyle(object a, object b) { } }
  public class ControlCollection : IEnumerable {
    public List<Control> Items = new List<Control>(); public Control Owner;
    public void Add(Control c) { c.Parent = Owner; Items.Add(c); } public void Add(Control c, int col, int row) { Add(c); }
    public void AddRange(Control[] cs) { foreach (Control c in cs) Add(c); } public void Clear() { Items.Clear(); }
    public Control this[int i] { get { return Items[i]; } }
    public int Count { get { return Items.Count; } } public IEnumerator GetEnumerator() { return Items.ToArray().GetEnumerator(); }
  }
  public class Control : RadeStub.Dyn {
    public ControlCollection Controls = new ControlCollection(); public string Text = ""; public bool Visible = true; public bool Enabled = true; public object Tag; public Control Parent;
    public bool IsDisposed; public int Width = 400, Height = 40, Left, Top;
    public Control() { Controls.Owner = this; }
    protected bool DoubleBuffered { get; set; }
    public Size ClientSize { get { return new Size(Width, Height); } set { Width = value.Width; Height = value.Height; } }
    public Size Size { get { return new Size(Width, Height); } set { Width = value.Width; Height = value.Height; } }
    public Rectangle Bounds { get { return new Rectangle(Left, Top, Width, Height); } set { Left = value.Left; Top = value.Top; Width = value.Width; Height = value.Height; } }
    public bool Focused { get { return RadeStub.Driver.Focus == this; } }
    public bool ContainsFocus { get { for (Control c = RadeStub.Driver.Focus; c != null; c = c.Parent) { if (c == this) return true; } return false; } }
    // The size the control asks for (no layout here): its own size; a label: its text in one line at its font; a button: its
    // text with 12 px padding, at least its MinimumSize (as Windows Forms AutoSize does).
    public virtual Size PreferredSize { get { return new Size(Width, Height); } }
    public bool Shown { get { for (Control c = this; c != null; c = c.Parent) { if (!c.Visible) return false; } return true; } }   // visible with every parent
    public bool Focus() { if (!Shown || !Enabled) return false; Control old = RadeStub.Driver.Focus; RadeStub.Driver.Focus = this; if (old != null && old != this) old.Fire("LostFocus", null); Fire("GotFocus", null); return true; }
    public void Invalidate() { } public void Dispose() { IsDisposed = true; } public void SuspendLayout() { } public void ResumeLayout() { } public void ResumeLayout(bool b) { } public void PerformLayout() { }
    public void PerformClick() { if (!Shown) throw new InvalidOperationException("click on a hidden control: " + Text); if (Enabled) Fire("Click", new RadeStub.Dyn()); }
    public void Repaint() { RadeStub.Dyn e = new RadeStub.Dyn(); e.Values["Graphics"] = new Graphics(); Fire("Paint", e); foreach (Control c in Controls) c.Repaint(); }
    public void Walk(List<Control> all) { all.Add(this); foreach (Control c in Controls) c.Walk(all); }
  }
  public class Panel : Control { } public class FlowLayoutPanel : Control { } public class PictureBox : Control { }
  public class Label : Control { public override Size PreferredSize { get { object f; int h = 18; if (Values.TryGetValue("Font", out f) && f is PSObject) f = ((PSObject)f).BaseObject; if (f is RadeDraw.Font) h = ((RadeDraw.Font)f).Height; return new Size((Text ?? "").Length * 7, h); } } }
  public class Bag { public int Count; public void Add(object o) { Count++; } public void Clear() { Count = 0; } }
  public class TableLayoutPanel : Control { public Bag ColumnStyles = new Bag(); public Bag RowStyles = new Bag(); public void SetColumnSpan(Control c, int n) { } }
  public class Button : Control { public override Size PreferredSize { get { object m; Size min = new Size(0, 0); if (Values.TryGetValue("MinimumSize", out m) && m is PSObject) m = ((PSObject)m).BaseObject; if (m is Size) min = (Size)m; return new Size(Math.Max((Text ?? "").Length * 7 + 24, min.Width), Math.Max(23, min.Height)); } } }
  public class TextBox : Control { }
  public class CheckBox : Control { bool on; public bool Checked { get { return on; } set { bool ch = on != value; on = value; if (ch) Fire("CheckedChanged", new RadeStub.Dyn()); } } }
  public class FolderBrowserDialog : RadeStub.Dyn { public string ShowDialog(object owner) { return "Cancel"; } public void Dispose() { } }
  public class Timer : RadeStub.Dyn { public bool On; public void Start() { On = true; if (!RadeStub.Driver.Timers.Contains(this)) RadeStub.Driver.Timers.Add(this); } public void Stop() { On = false; } }
  public class Form : Control {
    public bool Closed; public Form() { Width = 1020; Height = 760; }
    public string WindowState = "Normal";
    public Rectangle RestoreBounds { get { return new Rectangle(Left, Top, Width, Height); } }
    public System.Drawing.SizeF CurrentAutoScaleDimensions { get { return new System.Drawing.SizeF(RadeStub.Driver.FormDpi, RadeStub.Driver.FormDpi); } }   // 144 = the R24 device: the form scales 1.5 x while the screen dpi says 96
    public Control ActiveControl { get { return RadeStub.Driver.Focus; } }
    public void Activate() { }
    public void Close() { if (Closed) return; RadeStub.Dyn e = new RadeStub.Dyn(); e.Values["Cancel"] = false; Fire("FormClosing", e); if (!(e.Values["Cancel"] is bool && (bool)e.Values["Cancel"])) { Closed = true; IsDisposed = true; } }
    public void Key(string code) { RadeStub.Dyn e = new RadeStub.Dyn(); e.Values["KeyCode"] = code; e.Values["SuppressKeyPress"] = false; Fire("KeyDown", e); }
    public string ShowDialog() { RadeStub.Driver.ShownBy = "ShowDialog"; return Loop(); }
    public string Loop() {   // the window "runs": the Shown handlers, then the test user until it closes the window
      Fire("Shown", new RadeStub.Dyn());
      for (int i = 0; i < 400 && !Closed; i++) Application.DoEvents();
      if (!Closed) throw new InvalidOperationException("the test user did not close the window");
      return "OK";
    }
  }
  public static class Application {
    public static void EnableVisualStyles() { }
    public static void Run(Form f) {
      if (RadeStub.Driver.RunThrows) throw new InvalidOperationException("Starting a second message loop on a single thread is not a valid operation. Use Form.ShowDialog instead.");
      RadeStub.Driver.ShownBy = "Run"; f.Loop();
    }
    public static void DoEvents() {
      RadeStub.Driver.Pumps++;
      if (RadeStub.Driver.Pumps > 20000) throw new InvalidOperationException("the window waits and the test user has no answer");
      foreach (Timer t in RadeStub.Driver.Timers.ToArray()) if (t.On) t.Fire("Tick", new RadeStub.Dyn());
      if (RadeStub.Driver.Pump != null) RadeStub.Driver.Pump.Invoke();
    }
  }
  public static class SystemInformation { public static bool UIEffectsEnabled = true; public static int VerticalScrollBarWidth = 17; }
  public static class TextRenderer {
    public static Size MeasureText(string t, object f) { return new Size((t ?? "").Length * 7, 18); }
    public static Size MeasureText(string t, object f, Size s, TextFormatFlags fl) { int w = (t ?? "").Length * 7; int lines = Math.Max(1, (w + Math.Max(1, s.Width) - 1) / Math.Max(1, s.Width)); return new Size(Math.Min(w, Math.Max(1, s.Width)), 18 * lines); }   // a text that wraps at a width
    public static void DrawText(object g, string t, object f, Rectangle r, Color c, TextFormatFlags fl) { if (t == null) throw new ArgumentNullException("text"); }
  }
  public static class Clipboard { public static void SetText(string t) { if (string.IsNullOrEmpty(t)) throw new ArgumentNullException("text"); RadeStub.Driver.Clip = t; } }
  public class Screen { public Rectangle Bounds = new Rectangle(0, 0, 1280, 800); public Rectangle WorkingArea = new Rectangle(0, 0, 1280, 720); public static Screen FromControl(Control c) { return new Screen(); }
    public static Screen FromPoint(Point p) { return new Screen(); }
    public static Screen[] AllScreens { get { return RadeStub.Driver.Screens(); } } }
  public static class Cursor { public static Point Position { get { return new Point(100, 100); } } }
  public static class MessageBox { public static string Show(object owner, string text, string caption, MessageBoxButtons b, MessageBoxIcon i, MessageBoxDefaultButton d) { return "Yes"; } }
}

class Lq310Commands {
  // Reset & Basics
  static const String escInit =
      '\x1B\x40'; // Reset คืนค่าหน้าเครื่อง (ต้องตามด้วย Override เสมอ)
  static const String escPageLen = '\x1B\x43\x21'; // Set Page Length
  static const String escCancelSkip =
      '\x1B\x4F'; // Cancel Skip over perforation

  // Font Pitch
  static const String font10Cpi = '\x1B\x50';
  static const String font12Cpi = '\x1B\x4D';

  // Margins & Tabs
  static const String escLeftMargin0 = '\x1B\x6C\x00';
  static final String escSetTab = '\x1B\x44${String.fromCharCode(48)}\x00';

  // --- 🚀 THE MASTER'S OVERRIDES (หัวใจสำคัญในการแก้ปัญหา) --- //

  // 1. บังคับใช้ TIS-620 (สมอ.) ทับรอย KU42 ของลูกค้า
  static const String forceTIS620 = '\x1B\x74\x15';

  // 2. บังคับพิมพ์แบบ อัจฉริยะ (ITP) ทับรอย 3-Pass ของลูกค้า
  static const String forceITP = '\x1C\x70\x01';

  // 3. คำสั่งดันกระดาษ (Form Feed) แก้ปัญหาลูกค้าไม่เปิด เลื่อนฉีกกระดาษ
  static const String formFeed = '\x0C';
}

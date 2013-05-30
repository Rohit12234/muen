with System.Machine_Code;
with System.Storage_Elements;

with Skp;

with SK.CPU;
with SK.Descriptors;

package body Interrupts
is

   subtype ISR_Array is SK.Descriptors.ISR_Array (Skp.Vector_Range);
   ISRs : ISR_Array;
   pragma Import (C, ISRs, "isrlist");

   subtype IDT_Type is SK.Descriptors.IDT_Type (Skp.Vector_Range);
   IDT : IDT_Type := (others => SK.Descriptors.Null_Gate);

   --  IDT descriptor, loaded into IDTR.
   IDT_Descriptor : SK.Descriptors.Pseudo_Descriptor_Type;

   type GDT_Type is array (1 .. 3) of SK.Word64;
   GDT : GDT_Type;
   for GDT'Alignment use 8;

   --  GDT descriptor, loaded into GDTR.
   GDT_Descriptor : SK.Descriptors.Pseudo_Descriptor_Type;

   --  Setup GDT with two entries (code & stack) and load it into GDTR.
   procedure Load_GDT;

   --  Load IDT into IDTR.
   procedure Load_IDT;

   -------------------------------------------------------------------------

   procedure Initialize
   is
   begin
      SK.Descriptors.Setup_IDT (ISRs => ISRs,
                                IDT  => IDT);
      Load_GDT;
      Load_IDT;
   end Initialize;

   -------------------------------------------------------------------------

   procedure Load_GDT
   is
   begin
      GDT := GDT_Type'(1 => 0,
                       2 => 16#20980000000000#,
                       3 => 16#20930000000000#);
      GDT_Descriptor := SK.Descriptors.Create_Descriptor
        (Table_Address => SK.Word64
           (System.Storage_Elements.To_Integer (Value => GDT'Address)),
         Table_Length  => GDT'Length);
      System.Machine_Code.Asm
        (Template => "lgdt (%0)",
         Inputs   => (System.Address'Asm_Input ("r", GDT_Descriptor'Address)),
         Volatile => True);
   end Load_GDT;

   -------------------------------------------------------------------------

   procedure Load_IDT
   is
   begin
      IDT_Descriptor := SK.Descriptors.Create_Descriptor
        (Table_Address => SK.Word64
           (System.Storage_Elements.To_Integer (Value => IDT'Address)),
         Table_Length  => IDT'Length);
      SK.CPU.Lidt
        (Address => SK.Word64
           (System.Storage_Elements.To_Integer
              (Value => IDT_Descriptor'Address)));
   end Load_IDT;

end Interrupts;

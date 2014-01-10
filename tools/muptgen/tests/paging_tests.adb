--
--  Copyright (C) 2013, 2014  Reto Buerki <reet@codelabs.ch>
--  Copyright (C) 2013, 2014  Adrian-Ken Rueegsegger <ken@codelabs.ch>
--
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program.  If not, see <http://www.gnu.org/licenses/>.
--

with SK;

with Pt.Paging;

package body Paging_Tests
is

   use Ahven;
   use Pt.Paging;
   use type SK.Word64;

   -------------------------------------------------------------------------

   procedure Create_PD_Entry
   is
      E     : PD_Entry_Type;
      Addr  : constant SK.Word64     := 16#fffc800f0000#;
      Ref_E : constant PD_Entry_Type := 16#8000fffc800f000b#;
   begin
      E := Create_PD_Entry
        (Address      => Addr,
         Writable     => True,
         User_Access  => False,
         Map_Page     => False,
         Global       => False,
         Memory_Type  => WC,
         Exec_Disable => True);

      Assert (Condition => E = Ref_E,
              Message   => "PD entry mismatch");
      Assert (Condition => Get_PT_Address (E => E) = Addr,
              Message   => "Address mismatch");
   end Create_PD_Entry;

   -------------------------------------------------------------------------

   procedure Create_PDPT_Entry
   is
      E     : PDPT_Entry_Type;
      Addr  : constant SK.Word64       := 16#2b3c004000#;
      Ref_E : constant PDPT_Entry_Type := 16#8000002b3c00400b#;
   begin
      E := Create_PDPT_Entry
        (Address      => Addr,
         Writable     => True,
         User_Access  => False,
         Map_Page     => False,
         Global       => False,
         Memory_Type  => WC,
         Exec_Disable => True);

      Assert (Condition => E = Ref_E,
              Message   => "PDPT entry mismatch");
      Assert (Condition => Get_PD_Address (E => E) = Addr,
              Message   => "Address mismatch");
   end Create_PDPT_Entry;

   -------------------------------------------------------------------------

   procedure Create_PML4_Entry
   is
      E     : PML4_Entry_Type;
      Addr  : constant SK.Word64       := 16#1f1000#;
      Ref_E : constant PML4_Entry_Type := 16#80000000001f100b#;
   begin
      E := Create_PML4_Entry
        (Address       => Addr,
         Writable      => True,
         User_Access   => False,
         Writethrough  => True,
         Cache_Disable => False,
         Exec_Disable  => True);

      Assert (Condition => E = Ref_E,
              Message   => "PML4 entry mismatch");
      Assert (Condition => Get_PDPT_Address (E => E) = Addr,
              Message   => "Address mismatch");
   end Create_PML4_Entry;

   -------------------------------------------------------------------------

   procedure Create_PT_Entry
   is
      E     : PT_Entry_Type;
      Addr  : constant SK.Word64     := 16#100043f000#;
      Ref_E : constant PT_Entry_Type := 16#100043f10b#;
   begin
      E := Create_PT_Entry
        (Address      => Addr,
         Writable     => True,
         User_Access  => False,
         Global       => True,
         Memory_Type  => WC,
         Exec_Disable => False);

      Assert (Condition => E = Ref_E,
              Message   => "PT entry mismatch");
      Assert (Condition => Get_Address (E => E) = Addr,
              Message   => "Address mismatch");
   end Create_PT_Entry;

   -------------------------------------------------------------------------

   procedure Index_Calculation
   is
      PML4, PDPT, PD, PT : Table_Range;
   begin
      Get_Indexes (Address    => 0,
                   PML4_Index => PML4,
                   PDPT_Index => PDPT,
                   PD_Index   => PD,
                   PT_Index   => PT);
      Assert (Condition => PML4 = 0,
              Message   => "PML4 index mismatch (1)");
      Assert (Condition => PDPT = 0,
              Message   => "PDPT index mismatch (1)");
      Assert (Condition => PD = 0,
              Message   => "PD index mismatch (1)");
      Assert (Condition => PT = 0,
              Message   => "PT index mismatch (1)");

      Get_Indexes (Address    => SK.Word64'Last,
                   PML4_Index => PML4,
                   PDPT_Index => PDPT,
                   PD_Index   => PD,
                   PT_Index   => PT);
      Assert (Condition => PML4 = Table_Range'Last,
              Message   => "PML4 index mismatch (2)");
      Assert (Condition => PDPT = Table_Range'Last,
              Message   => "PDPT index mismatch (2)");
      Assert (Condition => PD = Table_Range'Last,
              Message   => "PD index mismatch (2)");
      Assert (Condition => PT = Table_Range'Last,
              Message   => "PT index mismatch (2)");

      Get_Indexes (Address    => 16#fffc80200f000#,
                   PML4_Index => PML4,
                   PDPT_Index => PDPT,
                   PD_Index   => PD,
                   PT_Index   => PT);
      Assert (Condition => PML4 = 511,
              Message   => "PML4 index mismatch (3)");
      Assert (Condition => PDPT = 288,
              Message   => "PDPT index mismatch (3)");
      Assert (Condition => PD = 16,
              Message   => "PD index mismatch (3)");
      Assert (Condition => PT = 15,
              Message   => "PT index mismatch (3)");
   end Index_Calculation;

   -------------------------------------------------------------------------

   procedure Initialize (T : in out Testcase)
   is
   begin
      T.Set_Name (Name => "Paging tests");
      T.Add_Test_Routine
        (Routine => Create_PML4_Entry'Access,
         Name    => "PML4 entry creation");
      T.Add_Test_Routine
        (Routine => Create_PDPT_Entry'Access,
         Name    => "PDPT entry creation");
      T.Add_Test_Routine
        (Routine => Create_PD_Entry'Access,
         Name    => "PD entry creation");
      T.Add_Test_Routine
        (Routine => Create_PT_Entry'Access,
         Name    => "PT entry creation");
      T.Add_Test_Routine
        (Routine => Index_Calculation'Access,
         Name    => "Paging structure index calculation");
   end Initialize;

end Paging_Tests;
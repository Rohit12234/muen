--
--  Copyright (C) 2013-2016  Reto Buerki <reet@codelabs.ch>
--  Copyright (C) 2013-2016  Adrian-Ken Rueegsegger <ken@codelabs.ch>
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

with Skp.Events;
with Skp.Interrupts;
with Skp.Scheduling;
with Skp.Subjects;

with SK.Constants;
with SK.CPU;
with SK.Apic;
with SK.VTd;
with SK.Power;
with SK.Dump;
with SK.Subjects.Debug;

package body SK.Scheduler
is

   -------------------------------------------------------------------------

   --  Inject pending interrupt into subject identified by ID. Sets interrupt
   --  window if interrupt(s) remain pending.
   procedure Inject_Interrupt (Subject_Id : Skp.Subject_Id_Type)
   with
      Global  => (Input  => Subjects.State,
                  In_Out => (Subjects_Interrupts.State, X86_64.State)),
      Depends =>
        ((Subjects_Interrupts.State,
          X86_64.State)              =>+ (Subjects_Interrupts.State,
                                          Subjects.State, Subject_Id))
   is
      Vector            : SK.Byte;
      Interrupt_Pending : Boolean;
   begin
      if Subjects.Accepts_Interrupts (ID => Subject_Id) then
         Subjects_Interrupts.Consume_Interrupt
           (Subject => Subject_Id,
            Found   => Interrupt_Pending,
            Vector  => Vector);

         if Interrupt_Pending then
            VMX.VMCS_Write
              (Field => Constants.VM_ENTRY_INTERRUPT_INFO,
               Value => Constants.VM_INTERRUPT_INFO_VALID +
                 SK.Word64 (Vector));
         end if;
      end if;

      Subjects_Interrupts.Has_Pending_Interrupt
        (Subject           => Subject_Id,
         Interrupt_Pending => Interrupt_Pending);

      if Interrupt_Pending then
         VMX.VMCS_Set_Interrupt_Window (Value => True);
      end if;
   end Inject_Interrupt;

   -------------------------------------------------------------------------

   --  Update scheduling information. If the end of the current major frame is
   --  reached the major frame start time is updated by adding the period of
   --  the just expired major frame to the current start value. Additionally,
   --  the minor frame index is reset and the major frame is switched to the
   --  one set by Tau0.
   --  On regular minor frame switches the minor frame index is incremented by
   --  one.
   --  The ID of the next subject to schedule is returned to the caller.
   procedure Update_Scheduling_Info (Next_Subject : out Skp.Subject_Id_Type)
   with
      Global  =>
        (Input  => (Tau0_Interface.State, CPU_Global.CPU_ID),
         In_Out => (CPU_Global.State, MP.Barrier, Scheduling_Info.State)),
      Depends =>
        (Next_Subject            =>  (Tau0_Interface.State, CPU_Global.State,
                                      CPU_Global.CPU_ID),
         (CPU_Global.State,
          MP.Barrier,
          Scheduling_Info.State) =>+ (CPU_Global.State, Tau0_Interface.State,
                                      CPU_Global.CPU_ID))

   is
      use type Skp.Scheduling.Major_Frame_Range;
      use type Skp.Scheduling.Minor_Frame_Range;
      use type Skp.Scheduling.Barrier_Index_Range;

      Current_Major_ID : constant Skp.Scheduling.Major_Frame_Range
        := CPU_Global.Get_Current_Major_Frame_ID;
      Current_Minor_ID : constant Skp.Scheduling.Minor_Frame_Range
        := CPU_Global.Get_Current_Minor_Frame_ID;

      --  Save current major frame CPU cycles for schedule info export.
      Current_Major_Frame_Start : constant SK.Word64
        := CPU_Global.Get_Current_Major_Start_Cycles;

      Next_Minor_ID : Skp.Scheduling.Minor_Frame_Range;
   begin
      if Current_Minor_ID < CPU_Global.Get_Current_Major_Length then

         --  Sync on minor frame barrier if necessary and switch to next
         --  minor frame in current major frame.

         declare
            Current_Barrier : constant Skp.Scheduling.Barrier_Index_Range
              := Skp.Scheduling.Get_Barrier
                (CPU_ID   => CPU_Global.CPU_ID,
                 Major_ID => Current_Major_ID,
                 Minor_ID => Current_Minor_ID);
         begin
            if Current_Barrier /= Skp.Scheduling.No_Barrier then
               MP.Wait_On_Minor_Frame_Barrier (Index => Current_Barrier);
            end if;
         end;

         Next_Minor_ID := Current_Minor_ID + 1;
      else

         --  Switch to first minor frame in next major frame.

         Next_Minor_ID := Skp.Scheduling.Minor_Frame_Range'First;

         MP.Wait_For_All;
         if CPU_Global.Is_BSP then
            declare

               --  Next major frame ID used to access the volatile New_Major
               --  variable. Do not move the declaration outside of this scope
               --  as it is only updated on the BSP. All other CPUs must get
               --  the value from CPU_Global.

               Next_Major_ID    : Skp.Scheduling.Major_Frame_Range;
               Next_Major_Start : SK.Word64;
            begin
               Tau0_Interface.Get_Major_Frame (ID => Next_Major_ID);

               --  Increment major frame start time by period of major frame
               --  that just ended.

               Next_Major_Start := CPU_Global.Get_Current_Major_Start_Cycles
                 + Skp.Scheduling.Major_Frames (Current_Major_ID).Period;

               CPU_Global.Set_Current_Major_Frame (ID => Next_Major_ID);
               CPU_Global.Set_Current_Major_Start_Cycles
                 (TSC_Value => Next_Major_Start);

               if Current_Major_ID /= Next_Major_ID then
                  MP.Set_Minor_Frame_Barrier_Config
                    (Config => Skp.Scheduling.Major_Frames
                       (Next_Major_ID).Barrier_Config);
               end if;
            end;
         end if;
         MP.Wait_For_All;
      end if;

      --  Update current minor frame globally.

      CPU_Global.Set_Current_Minor_Frame (ID => Next_Minor_ID);

      --  Subject switch.

      Next_Subject := CPU_Global.Get_Current_Subject_ID;

      --  Set scheduling information of scheduling group.

      Scheduling_Info.Set_Scheduling_Info
        (ID                 => Skp.Scheduling.Get_Scheduling_Group_ID
           (Subject_ID => Next_Subject),
         TSC_Schedule_Start => Current_Major_Frame_Start +
           Skp.Scheduling.Get_Deadline
             (CPU_ID   => CPU_Global.CPU_ID,
              Major_ID => Current_Major_ID,
              Minor_ID => Current_Minor_ID),
         TSC_Schedule_End   => CPU_Global.Get_Current_Major_Start_Cycles +
           Skp.Scheduling.Get_Deadline
             (CPU_ID   => CPU_Global.CPU_ID,
              Major_ID => CPU_Global.Get_Current_Major_Frame_ID,
              Minor_ID => Next_Minor_ID));
   end Update_Scheduling_Info;

   -------------------------------------------------------------------------

   procedure Set_VMX_Exit_Timer
   is
      Now      : constant SK.Word64 := CPU.RDTSC64;
      Deadline : SK.Word64;
      Cycles   : SK.Word64;
   begin

      --  Absolute deadline is given by start of major frame plus the number of
      --  CPU cycles until the end of the current minor frame relative to major
      --  frame start.

      Deadline := CPU_Global.Get_Current_Major_Start_Cycles +
        Skp.Scheduling.Get_Deadline
          (CPU_ID   => CPU_Global.CPU_ID,
           Major_ID => CPU_Global.Get_Current_Major_Frame_ID,
           Minor_ID => CPU_Global.Get_Current_Minor_Frame_ID);

      if Deadline > Now then
         Cycles := Deadline - Now;
      else
         Cycles := 0;
      end if;

      VMX.VMCS_Write (Field => Constants.GUEST_VMX_PREEMPT_TIMER,
                      Value => Cycles / 2 ** Skp.Scheduling.VMX_Timer_Rate);
   end Set_VMX_Exit_Timer;

   -------------------------------------------------------------------------

   --  Clear all state associated with the subject specified by ID and
   --  initialize to the values of the subject policy.
   procedure Init_Subject (ID : Skp.Subject_Id_Type)
   with
      Global  =>
        (Input  => (GDT.GDT_Pointer, Interrupts.State, VMX.Exit_Address),
         In_Out => (FPU.State, Subjects.State, Subjects_Events.State,
                    Subjects_MSR_Store.State, Subjects_Interrupts.State,
                    Timed_Events.State, VMX.VMCS_State, X86_64.State)),
      Depends =>
       ((FPU.State,
         Subjects_Events.State,
         Subjects_Interrupts.State,
         Subjects_MSR_Store.State,
         Timed_Events.State)        =>+ ID,
        VMX.VMCS_State              =>+ (ID, X86_64.State),
        (Subjects.State,
         X86_64.State)              =>+ (GDT.GDT_Pointer, ID, Interrupts.State,
                                         VMX.Exit_Address, X86_64.State))

   is
      Controls  : constant Skp.Subjects.VMX_Controls_Type
        := Skp.Subjects.Get_VMX_Controls (Subject_Id => ID);
      VMCS_Addr : constant SK.Word64
        := Skp.Subjects.Get_VMCS_Address (Subject_Id => ID);
      MSR_Count : constant SK.Word32
        := Skp.Subjects.Get_MSR_Count (Subject_Id => ID);
   begin
      FPU.Clear_State (ID => ID);
      Subjects.Clear_State (Id => ID);
      Subjects_Events.Clear_Events (ID => ID);
      Subjects_Interrupts.Init_Interrupts (Subject => ID);
      Timed_Events.Init_Event (Subject => ID);

      if MSR_Count > 0 then
         Subjects_MSR_Store.Clear_MSRs (ID => ID);
      end if;

      VMX.Reset (VMCS_Address => VMCS_Addr,
                 Subject_ID   =>  ID);
      VMX.Load  (VMCS_Address => VMCS_Addr);
      VMX.VMCS_Setup_Control_Fields
        (IO_Bitmap_Address  => Skp.Subjects.Get_IO_Bitmap_Address
           (Subject_Id => ID),
         MSR_Bitmap_Address => Skp.Subjects.Get_MSR_Bitmap_Address
           (Subject_Id => ID),
         MSR_Store_Address  => Skp.Subjects.Get_MSR_Store_Address
           (Subject_Id => ID),
         MSR_Count          => MSR_Count,
         Ctls_Exec_Pin      => Controls.Exec_Pin,
         Ctls_Exec_Proc     => Controls.Exec_Proc,
         Ctls_Exec_Proc2    => Controls.Exec_Proc2,
         Ctls_Exit          => Controls.Exit_Ctrls,
         Ctls_Entry         => Controls.Entry_Ctrls,
         CR0_Mask           => Skp.Subjects.Get_CR0_Mask
           (Subject_Id => ID),
         CR4_Mask           => Skp.Subjects.Get_CR4_Mask
           (Subject_Id => ID),
         Exception_Bitmap   => Skp.Subjects.Get_Exception_Bitmap
           (Subject_Id => ID));
      VMX.VMCS_Setup_Host_Fields;
      VMX.VMCS_Setup_Guest_Fields
        (PML4_Address => Skp.Subjects.Get_PML4_Address (Subject_Id => ID),
         EPT_Pointer  => Skp.Subjects.Get_EPT_Pointer (Subject_Id => ID),
         RIP_Value    => Skp.Subjects.Get_Entry_Point (Subject_Id => ID),
         RSP_Value    => Skp.Subjects.Get_Stack_Address (Subject_Id => ID),
         CR0_Value    => Skp.Subjects.Get_CR0 (Subject_Id => ID),
         CR4_Value    => Skp.Subjects.Get_CR4 (Subject_Id => ID),
         CS_Access    => Skp.Subjects.Get_CS_Access (Subject_Id => ID));

      Subjects.Save_State
        (Id   => ID,
         Regs => SK.Null_CPU_Regs);
   end Init_Subject;

   -------------------------------------------------------------------------

   procedure Init
   is
      use type Skp.CPU_Range;
   begin
      CPU_Global.Set_Scheduling_Groups
        (Data => Skp.Scheduling.Scheduling_Groups);

      --  Setup VMCS and state of subjects running on this logical CPU.

      for I in Skp.Subject_Id_Type loop
         if Skp.Subjects.Get_CPU_Id (Subject_Id => I) = CPU_Global.CPU_ID then
            Init_Subject (ID => I);
         end if;
      end loop;

      --  Load first subject and set preemption timer ticks.

      declare
         Now               : constant SK.Word64 := CPU.RDTSC64;
         Current_Subject   : constant Skp.Subject_Id_Type
           := CPU_Global.Get_Current_Subject_ID;
         Current_VMCS_Addr : constant SK.Word64
           := Skp.Subjects.Get_VMCS_Address (Subject_Id => Current_Subject);
      begin
         VMX.Load (VMCS_Address => Current_VMCS_Addr);
         Scheduling_Info.Set_Scheduling_Info
           (ID                 => Skp.Scheduling.Get_Scheduling_Group_ID
              (Subject_ID => Current_Subject),
            TSC_Schedule_Start => Now,
            TSC_Schedule_End   => Now + Skp.Scheduling.Get_Deadline
              (CPU_ID   => CPU_Global.CPU_ID,
               Major_ID => Skp.Scheduling.Major_Frame_Range'First,
               Minor_ID => Skp.Scheduling.Minor_Frame_Range'First));

         if CPU_Global.Is_BSP then

            --  Set minor frame barriers config.

            MP.Set_Minor_Frame_Barrier_Config
              (Config => Skp.Scheduling.Major_Frames
                 (Skp.Scheduling.Major_Frame_Range'First).Barrier_Config);

            --  Set initial major frame start time to now.

            CPU_Global.Set_Current_Major_Start_Cycles (TSC_Value => Now);
         end if;
      end;
   end Init;

   -------------------------------------------------------------------------

   --  Check if the specified subject has a pending target event. If one is
   --  found, the event is consumed by performing the corresponding action.
   procedure Handle_Pending_Target_Event (Subject_ID : Skp.Subject_Id_Type)
   with
      Global  =>
        (Input  => (GDT.GDT_Pointer, Interrupts.State, VMX.Exit_Address),
         In_Out => (FPU.State, Subjects.State, Subjects_Events.State,
                    Subjects_Interrupts.State, Subjects_MSR_Store.State,
                    Timed_Events.State, VMX.VMCS_State, X86_64.State)),
      Depends =>
        ((FPU.State,
          Subjects_Events.State,
          Subjects_Interrupts.State,
          Subjects_MSR_Store.State,
          Timed_Events.State)        =>+ (Subjects_Events.State, Subject_ID),
         VMX.VMCS_State              =>+ (Subject_ID, Subjects_Events.State,
                                          VMX.VMCS_State, X86_64.State),
         (Subjects.State,
          X86_64.State)              =>+ (GDT.GDT_Pointer, Interrupts.State,
                                          Subject_ID, Subjects_Events.State,
                                          VMX.Exit_Address, X86_64.State))
   is
      Found    : Boolean;
      Event_ID : Skp.Events.Event_Range;
   begin
      Subjects_Events.Consume_Event
        (Subject => Subject_ID,
         Found   => Found,
         Event   => Event_ID);

      if Found then
         declare
            Cur_Event : constant Skp.Events.Event_Action_Type
              := Skp.Events.Get_Target_Event (Subject_ID => Subject_ID,
                                              Event_Nr   => Event_ID);
         begin
            case Skp.Events.Get_Kind (Event_Action => Cur_Event)
            is
               when Skp.Events.No_Action        => null;
               when Skp.Events.Inject_Interrupt =>
                  SK.Subjects_Interrupts.Insert_Interrupt
                    (Subject => Subject_ID,
                     Vector  => SK.Byte (Skp.Events.Get_Vector
                       (Event_Action => Cur_Event)));
               when Skp.Events.Reset            =>
                  Init_Subject (ID => Subject_ID);
            end case;
         end;
      end if;
   end Handle_Pending_Target_Event;

   -------------------------------------------------------------------------

   --  Handle given source event of specified subject. If the event is of mode
   --  handover, the target subject ID is returned in Next_Subject, otherwise
   --  the parameter is set to the ID of the current subject.
   procedure Handle_Source_Event
     (Subject      :     Skp.Subject_Id_Type;
      Event        :     Skp.Events.Event_Entry_Type;
      Next_Subject : out Skp.Subject_Id_Type)
   with
      Global  =>
        (Input  => CPU_Global.CPU_ID,
         In_Out => (CPU_Global.State, Subjects_Events.State, X86_64.State)),
      Depends =>
        (Next_Subject            =>  (Subject, Event),
         (Subjects_Events.State,
          X86_64.State)          =>+ Event,
         CPU_Global.State        =>+ (Event, CPU_Global.CPU_ID,
                                      CPU_Global.State))
   is
      use type Skp.Events.Target_Event_Range;

      Dst_CPU : Skp.CPU_Range;
   begin
      Next_Subject := Subject;

      case Event.Source_Action
      is
         when Skp.Events.No_Action       => null;
         when Skp.Events.System_Reboot   =>
            Power.Reboot (Power_Cycle => True);
         when Skp.Events.System_Poweroff =>
            Power.Shutdown;
      end case;

      if Event.Target_Subject /= Skp.Invalid_Subject then
         if Event.Target_Event /= Skp.Events.Invalid_Target_Event then
            Subjects_Events.Set_Event_Pending
              (Subject  => Event.Target_Subject,
               Event_ID => Event.Target_Event);

            if Event.Send_IPI then
               Dst_CPU := Skp.Subjects.Get_CPU_Id
                 (Subject_Id => Event.Target_Subject);
               Apic.Send_IPI (Vector  => SK.Constants.IPI_Vector,
                              Apic_Id => SK.Byte (Dst_CPU));
            end if;
         end if;

         if Event.Handover then
            Next_Subject := Event.Target_Subject;
            CPU_Global.Set_Current_Subject_ID (Subject_ID => Next_Subject);
         end if;
      end if;
   end Handle_Source_Event;

   -------------------------------------------------------------------------

   --  Handle hypercall with given event number.
   procedure Handle_Hypercall
     (Current_Subject : Skp.Subject_Id_Type;
      Event_Nr        : SK.Word64)
   with
      Global  =>
        (Input  => CPU_Global.CPU_ID,
         In_Out => (CPU_Global.State, Subjects_Events.State,
                    Subjects.State, X86_64.State)),
      Depends =>
        (Subjects.State          =>+ Current_Subject,
         (Subjects_Events.State,
          X86_64.State)          =>+ (Current_Subject, Event_Nr),
         CPU_Global.State        =>+ (Current_Subject, Event_Nr,
                                      CPU_Global.CPU_ID, CPU_Global.State))
   is
      use type Skp.Events.Event_Entry_Type;

      Valid_Event_Nr  : Boolean;
      Event           : Skp.Events.Event_Entry_Type;
      Next_Subject_ID : Skp.Subject_Id_Type := Current_Subject;
   begin
      Valid_Event_Nr := Event_Nr <= SK.Word64 (Skp.Events.Event_Range'Last);
      if Valid_Event_Nr then
         Event := Skp.Events.Get_Source_Event
           (Subject_ID => Current_Subject,
            Event_Nr   => Skp.Events.Event_Range (Event_Nr));
         Handle_Source_Event
           (Subject      => Current_Subject,
            Event        => Event,
            Next_Subject => Next_Subject_ID);
      end if;

      pragma Debug (not Valid_Event_Nr or else Event = Skp.Events.Null_Event,
                    Dump.Print_Spurious_Event
                      (Current_Subject => Current_Subject,
                       Event_Nr        => Event_Nr));

      Subjects.Increment_RIP (ID => Current_Subject);

      --  If hypercall triggered a handover event, load new VMCS.

      if Current_Subject /= Next_Subject_ID then
         VMX.Load (VMCS_Address => Skp.Subjects.Get_VMCS_Address
                   (Subject_Id => Next_Subject_ID));
      end if;
   end Handle_Hypercall;

   -------------------------------------------------------------------------

   --  Handle external interrupt request with given vector.
   procedure Handle_Irq (Vector : SK.Byte)
   with
      Global  => (In_Out => (Subjects_Interrupts.State, Skp.IOMMU.State,
                             X86_64.State)),
      Depends => ((Subjects_Interrupts.State, Skp.IOMMU.State) =>+ Vector,
                   X86_64.State                                =>+ null)
   is
      Vect_Nr : Skp.Interrupts.Remapped_Vector_Type;
      Route   : Skp.Interrupts.Vector_Route_Type;
   begin
      if Vector >= Skp.Interrupts.Remap_Offset
        and then Vector /= SK.Constants.IPI_Vector
      then
         if Vector = SK.Constants.VTd_Fault_Vector then
            VTd.Process_Fault;
         else
            Vect_Nr := Skp.Interrupts.Remapped_Vector_Type (Vector);
            Route   := Skp.Interrupts.Vector_Routing (Vect_Nr);
            if Route.Subject in Skp.Subject_Id_Type then
               Subjects_Interrupts.Insert_Interrupt
                 (Subject => Route.Subject,
                  Vector  => SK.Byte (Route.Vector));
            end if;

            pragma Debug (Route.Subject not in Skp.Subject_Id_Type,
                          Dump.Print_Message_8 (Msg  => "Spurious IRQ vector",
                                                Item => Vector));
         end if;
      end if;

      pragma Debug (Vector < Skp.Interrupts.Remap_Offset,
                    Dump.Print_Message_8 (Msg  => "IRQ with invalid vector",
                                          Item => Vector));
      Apic.EOI;
   end Handle_Irq;

   -------------------------------------------------------------------------

   --  Handle trap with given number using trap table of current subject.
   procedure Handle_Trap
     (Current_Subject : Skp.Subject_Id_Type;
      Trap_Nr         : SK.Word16)
   with
      Global  =>
        (Input  => CPU_Global.CPU_ID,
         In_Out => (CPU_Global.State, Subjects_Events.State, X86_64.State)),
      Depends =>
        ((Subjects_Events.State,
          X86_64.State)          =>+ (Current_Subject, Trap_Nr),
         CPU_Global.State        =>+ (CPU_Global.State, CPU_Global.CPU_ID,
                                      Current_Subject, Trap_Nr))
   is
      use type Skp.Dst_Vector_Range;
      use type Skp.Events.Event_Entry_Type;

      Trap_Entry      : Skp.Events.Event_Entry_Type;
      Next_Subject_ID : Skp.Subject_Id_Type;
      Valid_Trap_Nr   : Boolean;

      ----------------------------------------------------------------------

      procedure Panic_No_Trap_Handler
      with
         Global  => (In_Out => (X86_64.State)),
         Depends => (X86_64.State =>+ null),
         No_Return
      is
      begin
         pragma Debug (Dump.Print_Message_16
                       (Msg  => ">>> No handler for trap",
                        Item => Trap_Nr));
         pragma Debug (Subjects.Debug.Print_State (ID => Current_Subject));

         CPU.Panic;
      end Panic_No_Trap_Handler;

      ----------------------------------------------------------------------

      procedure Panic_Unknown_Trap
      with
         Global  => (In_Out => (X86_64.State)),
         Depends => (X86_64.State =>+ null),
         No_Return
      is
      begin
         pragma Debug (Dump.Print_Message_16 (Msg  => ">>> Unknown trap",
                                              Item => Trap_Nr));
         pragma Debug (Subjects.Debug.Print_State (ID => Current_Subject));

         CPU.Panic;
      end Panic_Unknown_Trap;
   begin
      Valid_Trap_Nr := Trap_Nr <= SK.Word16 (Skp.Events.Trap_Range'Last);
      if not Valid_Trap_Nr then
         Panic_Unknown_Trap;
      end if;

      Trap_Entry := Skp.Events.Get_Trap
        (Subject_ID => Current_Subject,
         Trap_Nr    => Skp.Events.Trap_Range (Trap_Nr));

      if Trap_Entry = Skp.Events.Null_Event then
         Panic_No_Trap_Handler;
      end if;

      Handle_Source_Event
        (Subject      => Current_Subject,
         Event        => Trap_Entry,
         Next_Subject => Next_Subject_ID);

      --  If trap triggered a handover, load new VMCS.

      if Current_Subject /= Next_Subject_ID then
         VMX.Load (VMCS_Address => Skp.Subjects.Get_VMCS_Address
                   (Subject_Id => Next_Subject_ID));
      end if;
   end Handle_Trap;

   -------------------------------------------------------------------------

   --  Minor frame ticks consumed, handle VMX preemption timer expiry.
   procedure Handle_Timer_Expiry (Current_Subject : Skp.Subject_Id_Type)
   with
      Global  =>
        (Input  => (Tau0_Interface.State, CPU_Global.CPU_ID),
         In_Out => (CPU_Global.State, MP.Barrier, Scheduling_Info.State,
                    Subjects_Events.State, Timed_Events.State, X86_64.State)),
      Depends =>
        ((Timed_Events.State,
          Subjects_Events.State,
          CPU_Global.State)      =>+ (CPU_Global.State, CPU_Global.CPU_ID,
                                      Tau0_Interface.State,
                                      Timed_Events.State, X86_64.State),
         X86_64.State            =>+ (Current_Subject, CPU_Global.State,
                                      CPU_Global.CPU_ID, Tau0_Interface.State,
                                      Timed_Events.State),
         (MP.Barrier,
          Scheduling_Info.State) =>+ (CPU_Global.State, CPU_Global.CPU_ID,
                                      Tau0_Interface.State))
   is
      Next_Subject_ID : Skp.Subject_Id_Type;
   begin
      Update_Scheduling_Info (Next_Subject => Next_Subject_ID);

      --  Check and possibly handle timed event of subject.

      declare
         Event_Subj    : constant Skp.Subject_Id_Type := Next_Subject_ID;
         Trigger_Value : SK.Word64;
         Event_Nr      : Skp.Events.Event_Range;
         TSC_Now       : constant SK.Word64 := CPU.RDTSC64;
      begin

         --  Set expired event pending.

         Timed_Events.Get_Event (Subject           => Event_Subj,
                                 TSC_Trigger_Value => Trigger_Value,
                                 Event_Nr          => Event_Nr);
         if Trigger_Value <= TSC_Now then
            Handle_Source_Event
              (Subject      => Event_Subj,
               Event        => Skp.Events.Get_Source_Event
                 (Subject_ID => Event_Subj,
                  Event_Nr   => Skp.Events.Target_Event_Range (Event_Nr)),
               Next_Subject => Next_Subject_ID);
            Timed_Events.Clear_Event (Subject => Event_Subj);
         end if;
      end;

      if Current_Subject /= Next_Subject_ID then

         --  New minor frame contains different subject -> Load VMCS.

         VMX.Load (VMCS_Address => Skp.Subjects.Get_VMCS_Address
                   (Subject_Id => Next_Subject_ID));
      end if;
   end Handle_Timer_Expiry;

   -------------------------------------------------------------------------

   procedure Handle_Vmx_Exit (Subject_Registers : in out SK.CPU_Registers_Type)
   is
      Exit_Reason       : SK.Word64;
      Basic_Exit_Reason : SK.Word16;
      Current_Subject   : Skp.Subject_Id_Type;
   begin
      Current_Subject := CPU_Global.Get_Current_Subject_ID;

      VMX.VMCS_Read (Field => Constants.VMX_EXIT_REASON,
                     Value => Exit_Reason);
      Basic_Exit_Reason := SK.Word16 (Exit_Reason and 16#ffff#);

      Subjects.Save_State (Id   => Current_Subject,
                           Regs => Subject_Registers);

      FPU.Save_State (ID => Current_Subject);

      if Basic_Exit_Reason = Constants.EXIT_REASON_EXTERNAL_INT then
         Handle_Irq (Vector => SK.Byte'Mod (Subjects.Get_Interrupt_Info
                     (Id => Current_Subject)));
      elsif Basic_Exit_Reason = Constants.EXIT_REASON_VMCALL then
         Handle_Hypercall (Current_Subject => Current_Subject,
                           Event_Nr        => Subject_Registers.RAX);
      elsif Basic_Exit_Reason = Constants.EXIT_REASON_TIMER_EXPIRY then
         Handle_Timer_Expiry (Current_Subject => Current_Subject);
      elsif Basic_Exit_Reason = Constants.EXIT_REASON_INTERRUPT_WINDOW then

         --  Resume subject to inject pending interrupt.

         VMX.VMCS_Set_Interrupt_Window (Value => False);
      else
         Handle_Trap (Current_Subject => Current_Subject,
                      Trap_Nr         => Basic_Exit_Reason);
      end if;

      Current_Subject := CPU_Global.Get_Current_Subject_ID;
      Handle_Pending_Target_Event (Subject_ID => Current_Subject);
      Inject_Interrupt (Subject_Id => Current_Subject);

      Set_VMX_Exit_Timer;
      FPU.Restore_State (ID => Current_Subject);
      Subjects.Restore_State
        (Id   => Current_Subject,
         Regs => Subject_Registers);
   end Handle_Vmx_Exit;

end SK.Scheduler;

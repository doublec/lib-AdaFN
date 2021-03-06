 
with System.Address_To_Access_Conversions;
with Ada.Unchecked_Conversion;
with Ada.Unchecked_Deallocation;
with Interfaces.C; use Interfaces.C;
with Interfaces.C.Strings;
with System;

package body GNU.DB.PostgreSQL is
   pragma Linker_Options ("-lpq");

   package C  renames Interfaces.C;
   package CS renames Interfaces.C.Strings;

   subtype char_array is C.char_array;
   subtype chars_ptr  is CS.chars_ptr;

   function To_Result is new Ada.Unchecked_Conversion (System.Address,
                                                       PGresult);
   function To_Addr is new Ada.Unchecked_Conversion (PGresult,
                                                     System.Address);

   function To_Conn is new Ada.Unchecked_Conversion (System.Address,
                                                     Connection_Handle);
   function To_Addr is new Ada.Unchecked_Conversion (Connection_Handle,
                                                     System.Address);

   protected body PGConn is

      function Handle return Connection_Handle is
      begin
         return C_Connection;
      end Handle;

      procedure Reset is
         procedure PQreset (Connection : System.Address);
         pragma Import (C, PQreset, "PQreset");
      begin
         PQreset (To_Addr (C_Connection));
      end Reset;

      function Error return String is
         function PQerr (Conn : System.Address) return chars_ptr;
         pragma Import (C, PQerr, "PQerrorMessage");
      begin
         return CS.Value (PQerr (To_Addr (C_Connection)));
      end Error;

      function Status return ConnStatus is
         function PQstatus (Conn : System.Address) return Interfaces.C.int;
         pragma Import (C, PQstatus, "PQstatus");
      begin
         return ConnStatus'Val (PQstatus (To_Addr (C_Connection)));
      end Status;

      procedure Close is
         procedure PQfinish (Connection : System.Address);
         pragma Import (C, PQfinish, "PQfinish");
      begin
         if C_Connection /= Null_Connection then
            PQfinish (To_Addr (C_Connection));
            C_Connection := Null_Connection;
         end if;
      end Close;

      function PID return Backend_PID is
         function PQpid (Conn : System.Address) return Interfaces.C.int;
         pragma Import (C, PQpid, "PQbackendPID");
         function To_PID is new Ada.Unchecked_Conversion
           (Source => Interfaces.C.int, Target => Backend_PID);
      begin
         return To_PID (PQpid (To_Addr (C_Connection)));
      end PID;

      procedure Execute (Res   : out Result;
                         Query : in  String) is
         function PQexec (Conn : System.Address;
                          Qry  : chars_ptr) return System.Address;
         pragma Import (C, PQexec, "PQexec");

         P : chars_ptr := CS.New_String (Query);
         R : constant PGresult :=
           To_Result (PQexec (To_Addr (C_Connection), P));
         Stat : ExecStatus;
      begin
         CS.Free (P);
         if R = Null_Result then
            raise PostgreSQL_Error;
         else
            Res.Res := R;
            Stat    := Status (Res);
            if Stat = PGRES_FATAL_ERROR then
               raise PostgreSQL_Error;
            end if;
         end if;
      end Execute;

      procedure Empty_Result (Res    : out Result;
                              Status : in  ExecStatus) is
         function PQemptyRes (Conn   : System.Address;
                              Status : C.int) return System.Address;
         pragma Import (C, PQemptyRes, "PQmakeEmptyPGresult");
         R : constant PGresult :=
           To_Result (PQemptyRes (To_Addr (C_Connection),
                                  ExecStatus'Pos (Status)));
      begin
         if R = Null_Result then
            raise PostgreSQL_Error;
         else
            Res.Res := R;
         end if;
      end Empty_Result;

      procedure SetNonBlocking
      is
         function PQnonblocking (Conn : System.Address)
                                 return Interfaces.C.int;
         pragma Import (C, PQnonblocking, "PQsetnonblocking");
         R : constant Interfaces.C.Int :=
           PQnonblocking (To_Addr (C_Connection));
      begin
         null;
      end SetNonBlocking;

      function IsNonBlocking return Boolean
      is
         function PQisnonblocking (Conn : System.Address)
                                   return Interfaces.C.int;
         pragma Import (C, PQisnonblocking, "PQisnonblocking");
         R : constant Interfaces.C.Int :=
           PQisnonblocking (To_Addr (C_Connection));
      begin
         if R /= 0 then
            return True;
         else
            return False;
         end if;
      end IsNonBlocking;

      function SendQuery (Query : in String) return boolean
      is
         function PQsendQuery (Conn : System.Address;
                               Qry  : chars_ptr) return Interfaces.C.int;
         pragma Import (C, PQsendQuery, "PQsendQuery");
         P : chars_ptr := CS.New_String (Query);
         R : constant Interfaces.C.int :=
           PQsendQuery (To_Addr (C_Connection), P);
      begin
         if R /= 0 then
            return True;
         else
            return False;
         end if;
      end SendQuery;

      procedure GetResult (Res  : out Result;
                           Done : out Boolean)
      is
         function PQgetResult (Conn : System.Address) return System.Address;
         pragma Import (C, PQgetResult, "PQgetResult");
         R : constant PGResult :=
           To_Result (PQgetResult (To_Addr (C_Connection)));
      begin
         if R = Null_Result then
            Done := True;
         else
            Res.Res := R;
            Done := False;
         end if;
      end GetResult;

      function ConsumeInput return Boolean
      is
         function PQconsumeInput (Conn : System.Address)
                                  return Interfaces.C.int;
         pragma Import (C, PQconsumeInput, "PQconsumeInput");
         R : constant Interfaces.C.Int :=
           PQconsumeInput (To_Addr (C_Connection));
      begin
         if R /= 0 then
            return True;
         else
            return False;
         end if;
      end ConsumeInput;

      function Flush return Boolean
      is
         function PQflush (Conn : System.Address) return Interfaces.C.int;
         pragma Import (C, PQflush, "PQflush");
         R : constant Interfaces.C.Int := PQflush (To_Addr (C_Connection));
      begin
         if R = 0 then
            return True;
         else
            return False;
         end if;
      end Flush;

      function IsBusy return Boolean
      is
         function PQisBusy (Conn : System.Address) return Interfaces.C.int;
         pragma Import (C, PQisBusy, "PQisBusy");
         R : constant Interfaces.C.Int := PQisBusy (To_Addr (C_Connection));
      begin
         if R /= 0 then
            return True;
         else
            return False;
         end if;
      end IsBusy;


      function RequestCancel return Boolean
      is
         function PQrequestCancel (Conn : System.Address)
                                   return Interfaces.C.int;
         pragma Import (C, PQrequestCancel, "PQrequestCancel");
         R : constant Interfaces.C.Int :=
           PQrequestCancel (To_Addr (C_Connection));
      begin
         if R /= 0 then
            return True;
         else
            return False;
         end if;
      end RequestCancel;


      function Socket return Interfaces.C.int
      is
         function PQsocket (Conn : System.Address) return Interfaces.C.int;
         pragma Import (C, PQsocket, "PQsocket");
         R : constant Interfaces.C.Int := PQsocket (To_Addr (C_Connection));
      begin
         return R;
      end Socket;


      procedure Notifies (Message : out Notification;
                          Done    : out Boolean)
      is
         function PQnotifies (Conn : System.Address) return System.Address;
         pragma Import (C, PQnotifies, "PQnotifies");
         procedure Free (Addr : System.Address);
         pragma Import (C, Free, "free");
         type NotiPtr is access all Notification;
         package P is new System.Address_To_Access_Conversions (Notification);
         function Cvt is new Ada.Unchecked_Conversion (P.Object_Pointer,
                                                       NotiPtr);
         N : NotiPtr;
         A : constant System.Address := PQnotifies (To_Addr (C_Connection));
      begin
         N := Cvt (P.To_Pointer (A));
         if N /= null then
            Message := N.all;
            Free (A);
            Done := False;
         else
            Done := True;
         end if;
      end Notifies;

   end PGConn;

   procedure Initialize (Object : in out Database) is
   begin
      null;
   end Initialize;

   procedure Finalize (Object : in out Database) is
      procedure Free is
         new Ada.Unchecked_Deallocation(PGConn,Connection_Pointer);
   begin
      Object.Connection.Close;
      if Object.Connection /= null then
         Free( Object.Connection );
      end if;
   end Finalize;

   function Connect (Params : access String) return Connection_Handle is
      function PQConnect (Options :  char_array) return System.Address;
      pragma Import (C, PQConnect, "PQconnectdb");

      Conn : Connection_Handle;
   begin
      Conn := To_Conn (PQConnect (C.To_C (Params.all)));
      if Conn = Null_Connection then
         raise PostgreSQL_Error;
      else
         return Conn;
      end if;
   end Connect;

   procedure Reset (DB : in Database'Class) is
   begin
      DB.Connection.Reset;
   end Reset;

   type C_Accessor is access function (Conn : System.Address) return chars_ptr;
   pragma Convention (C, C_Accessor);

   generic
      Accessor : C_Accessor;
   function Connection_Accessor (DB : in Database'Class) return String;

   function  Connection_Accessor (DB : in Database'Class) return String is
   begin
      return CS.Value (Accessor.all (To_Addr (DB.Connection.Handle)));
   end Connection_Accessor;

   function PQdb (Conn : System.Address) return chars_ptr;
   pragma Import (C, PQdb, "PQdb");
   function Get_Name is new Connection_Accessor (Accessor => PQdb'access);

   function PQuser (Conn : System.Address) return chars_ptr;
   pragma Import (C, PQuser, "PQuser");
   function Get_User is new Connection_Accessor (Accessor => PQuser'access);

   function PQpass (Conn : System.Address) return chars_ptr;
   pragma Import (C, PQpass, "PQpass");
   function Get_Pass is new Connection_Accessor (Accessor => PQpass'access);

   function PQhost (Conn : System.Address) return chars_ptr;
   pragma Import (C, PQhost, "PQhost");
   function Get_Host is new Connection_Accessor (Accessor => PQhost'access);

   function PQport (Conn : System.Address) return chars_ptr;
   pragma Import (C, PQport, "PQport");
   function Get_Port is new Connection_Accessor (Accessor => PQport'access);

   function PQtty (Conn : System.Address) return chars_ptr;
   pragma Import (C, PQtty, "PQtty");
   function Get_TTY is new Connection_Accessor (Accessor => PQtty'access);

   function PQopt (Conn : System.Address) return chars_ptr;
   pragma Import (C, PQopt, "PQoptions");
   function Get_Options is new Connection_Accessor (Accessor => PQopt'access);

   function Name     (DB : in Database'Class) return String renames Get_Name;
   function User     (DB : in Database'Class) return String renames Get_User;
   function Password (DB : in Database'Class) return String renames Get_Pass;
   function Host     (DB : in Database'Class) return String renames Get_Host;
   function Port     (DB : in Database'Class) return String renames Get_Port;
   function TTY      (DB : in Database'Class) return String renames Get_TTY;
   function Options  (DB : in Database'Class) return String
     renames Get_Options;

   function Error    (DB : in Database'Class) return String is
   begin
      return DB.Connection.Error;
   end Error;

   function Status (DB : in Database'Class) return ConnStatus is
   begin
      return DB.Connection.Status;
   end Status;

   function Server_PID (DB : in Database'Class) return Backend_PID is
   begin
      return DB.Connection.PID;
   end Server_PID;

   procedure Execute (Res   : out Result;
                      DB    : in  Database'Class;
                      Query : String) is
   begin
      DB.Connection.Execute (Res, Query);
   end Execute;

   procedure Make_Empty_Result (Res    : out Result;
                                DB     : in  Database'Class;
                                Status : in  ExecStatus := PGRES_EMPTY_QUERY)
   is
   begin
      DB.Connection .Empty_Result (Res, Status);
   end Make_Empty_Result;

   procedure Initialize (Object : in out Result) is
   begin
      null;
   end Initialize;

   procedure Finalize (Object : in out Result) is
      procedure PQclear (Res : in System.Address);
      pragma Import (C, PQclear, "PQclear");
   begin
      if Object.Res /= Null_Result then
         PQclear (To_Addr (Object.Res));
         Object.Res := Null_Result;
      end if;
   end Finalize;

   function Status (Res : in Result) return ExecStatus is
      function PQresStatus (Conn : System.Address) return Interfaces.C.int;
      pragma Import (C, PQresStatus, "PQresultStatus");
   begin
      return ExecStatus'Val (PQresStatus (To_Addr (Res.Res)));
   end Status;

   function Status (Status : in ExecStatus) return String is
      function PQresStat (stat : Interfaces.C.int) return chars_ptr;
      pragma Import (C, PQresStat, "PQresStatus");
   begin
      return CS.Value (PQresStat(ExecStatus'Pos (Status)));
   end Status;

   function Status (Res : in Result) return String is
      Stat :  constant ExecStatus := Status (Res);
   begin
      return Status (Stat);
   end Status;

   function Error (Res : in Result) return String is
      function PQresErr (Res : System.Address) return chars_ptr;
      pragma Import (C, PQresErr, "PQresultErrorMessage");
   begin
      return CS.Value (PQresErr (To_Addr (Res.Res)));
   end Error;

   function Quote_Identifier (Identifier : String) return String is
   begin
      return '"' & Identifier & '"';
   end Quote_Identifier;

   type C_Info is access function (Res : System.Address) return C.int;
   pragma Convention (C, C_Info);

   generic
      Accessor : C_Info;
   function Info_Accessor (Res : in Result) return Integer;

   function  Info_Accessor (Res : in Result) return Integer is
   begin
      return Integer (Accessor.all (To_Addr (Res.Res)));
   end Info_Accessor;

   function PQntuples (Res : System.Address) return C.int;
   pragma Import (C, PQntuples, "PQntuples");
   function Get_Count is new Info_Accessor (Accessor => PQntuples'access);

   function PQnfields (Res : System.Address) return C.int;
   pragma Import (C, PQnfields, "PQnfields");
   function Get_FCount is new Info_Accessor (Accessor => PQnfields'access);

   function PQbinaryTuples (Res : System.Address) return C.int;
   pragma Import (C, PQbinaryTuples, "PQbinaryTuples");
   function Get_BinaryTuples is new
     Info_Accessor (Accessor => PQbinaryTuples'Access);

   function Tuple_Count (Res : Result) return Tuple_Index is
   begin
      return Tuple_Index (Get_Count (Res));
   end Tuple_Count;

   function Field_Count (Res : Result) return Field_Index is
   begin
      return Field_Index (Get_FCount (Res));
   end Field_Count;

   function Field_Name  (Res   : Result;
                         Index : Field_Index) return String is
      function PQfname (Res : System.Address;
                        Idx : C.int) return chars_ptr;
      pragma Import (C, PQfname, "PQfname");
   begin
      return CS.Value (PQfname (To_Addr (Res.Res),
                                C.int (Index)));
   end Field_Name;

   procedure Field_Lookup (Res   : in Result;
                           Name  : in String;
                           Index : out Field_Index;
                           Found : out Boolean) is
      function PQfnumber (Res  : System.Address;
                          Name : chars_ptr) return C.int;
      pragma Import (C, PQfnumber, "PQfnumber");
      P : chars_ptr := CS.New_String (Name);
      I : constant C.int := PQfnumber (To_Addr (Res.Res), P);
   begin
      CS.Free (P);
      if I < 0 then
         Found := False;
         Index := Field_Index'Last;
      else
         Found := True;
         Index := Field_Index (I);
      end if;
   end Field_Lookup;

   function Is_Binary (Res   : Result;
                       Index : Field_Index) return Boolean is
      I : constant Integer := Get_BinaryTuples (Res);
   begin
      if I /= 0 then
         return True;
      else
         return False;
      end if;
   end Is_Binary;

   function Field_Type  (Res   : Result;
                         Index : Field_Index) return TypeID is
      function PQftype (Res : System.Address;
                        Idx : C.int) return TypeID;
      pragma Import (C, PQftype, "PQftype");
   begin
      return PQftype (To_Addr (Res.Res), C.Int (index));
   end Field_Type;

   procedure Value (Res     : in  Result;
                    Tuple   : in  Tuple_Index;
                    Field   : in  Field_Index;
                    Pointer : out System.Address)
   is
      function Cvt is new Ada.Unchecked_Conversion (chars_ptr,
                                                    System.Address);
      function PQgetvalue (Res   : System.Address;
                           Tuple : C.int;
                           Field : C.int) return chars_ptr;
      pragma Import (C, PQgetvalue, "PQgetvalue");
      P : constant chars_ptr := PQgetvalue (To_Addr (Res.Res),
                                            C.int (Tuple),
                                            C.int (Field));
   begin
      Pointer := Cvt (P);
   end Value;

   function Value (Res   : Result;
                   Tuple : Tuple_Index := 0;
                   Field : Field_Index := 0) return String is
      function PQgetvalue (Res   : System.Address;
                           Tuple : C.int;
                           Field : C.int) return chars_ptr;
      pragma Import (C, PQgetvalue, "PQgetvalue");
      P : constant chars_ptr := PQgetvalue (To_Addr (Res.Res),
                                            C.int (Tuple),
                                            C.int (Field));
   begin
      if Is_Binary (Res, Field) then
         raise PostgreSQL_Error;
      end if;
      return CS.Value (P);
   end Value;

   function Value (Res        : Result;
                   Tuple      : Tuple_Index := 0;
                   Field_Name : String ) return String is
      Found : Boolean;
      Idx   : Field_Index;
   begin
      Field_Lookup (Res, Field_Name, Idx, Found);
      if Found then
         return Value (Res, Tuple, Idx);
      else
         raise PostgreSQL_Error;
      end if;
   end Value;

   function Field_Size  (Res   : Result;
                         Field : Field_Index) return Integer is
      function PQfsize (Res : System.Address;
                        Idx : C.int) return C.int;
      pragma Import (C, PQfsize, "PQfsize");
   begin
      return Integer (PQfsize (To_Addr (Res.Res), C.int (Field)));
   end Field_Size;

   function Field_Modification (Res   : Result;
                                Field : Field_Index) return Integer is
      function PQfmod (Res : System.Address;
                       Idx : C.int) return C.int;
      pragma Import (C, PQfmod, "PQfmod");
   begin
      return Integer (PQfmod (To_Addr (Res.Res), C.int (Field)));
   end Field_Modification;

   function Field_Length (Res   : Result;
                          Tuple : Tuple_Index;
                          Field : Field_Index) return Natural is
      function PQgetlen (Res : System.Address;
                         Row : C.int;
                         Idx : C.int) return C.int;
      pragma Import (C, PQgetlen, "PQgetlength");
   begin
      return natural (PQgetlen (To_Addr (Res.Res),
                                C.Int (Tuple),
                                C.int (Field)));
   end Field_Length;

   function Is_Null (Res   : Result;
                     Tuple : Tuple_Index;
                     Field : Field_Index) return Boolean is
      use type C.int;
      function PQisnull (Res : System.Address;
                         Row : C.int;
                         Idx : C.int) return C.int;
      pragma Import (C, PQisnull, "PQgetisnull");

      R : constant C.int := PQisnull (To_Addr (Res.Res),
                                      C.Int (Tuple),
                                      C.int (Field));
   begin
      if R = 0 then
         return False;
      else
         return True;
      end if;
   end Is_Null;

   function Command_Status (Res : in Result) return String is
      function PQcmdStatus (Res : System.Address) return chars_ptr;
      pragma Import (C, PQcmdStatus, "PQcmdStatus");
   begin
      return CS.Value (PQcmdStatus (To_Addr (Res.Res)));
   end Command_Status;

   function Command_Tuples (Res : in Result) return String is
      function PQcmdTuples (Res : System.Address) return chars_ptr;
      pragma Import (C, PQcmdTuples, "PQcmdTuples");
   begin
      return CS.Value (PQcmdTuples (To_Addr (Res.Res)));
   end Command_Tuples;

   function Command_Tuples (Res : in Result) return Natural is
      S : constant String := Command_Tuples (Res);
   begin
      if S = "" then
         return 0;
      else
         return Natural'Value (S);
      end if;
   end Command_Tuples;

   function OID_Value (Res : in Result) return OID is
      function PQoidValue (Res : System.Address) return OID;
      pragma Import (C, PQoidValue, "PQoidValue");
   begin
      return PQoidValue (To_Addr (Res.Res));
   end OID_Value;

   --  -----------------------------------------------------------------------

   procedure Load_TypeInfo (DB  : in  Database'Class;
                            Typ : in  TypeID := InvalidTypeID;
                            R   : out TypeInfo)
   is
   begin
      if Typ = InvalidTypeID then
         Execute (R,
                  DB, "SELECT * FROM pg_type");
      else
         Execute (R,
                  DB, "SELECT * FROM pg_type WHERE OID=" & TypeID'Image (Typ));
      end if;
   end Load_TypeInfo;

   function Value (Res        : TypeInfo;
                   Tuple      : Tuple_Index := 0;
                   Field_Name : String) return String
   is
   begin
      return Value (Result (Res), Tuple, Field_Name);
   end Value;

   procedure Set_Non_Blocking (DB : in Database'Class) is
   begin
      DB.Connection.SetNonBlocking;
   end Set_Non_Blocking;

   function Is_Non_Blocking (DB : in Database'Class) return Boolean
   is
   begin
      return DB.Connection.IsNonBlocking;
   end Is_Non_Blocking;

   function Send_Query (DB    : in Database'Class;
                        Query : in String) return Boolean
   is
   begin
      return DB.Connection.SendQuery (Query);
   end Send_Query;

   procedure Get_Result (DB  :  in  Database'Class;
                         Res :  out Result;
                         Done : out Boolean)
   is
   begin
      DB.Connection.GetResult (Res, Done);
   end Get_Result;

   function Consume_Input (DB : in Database'Class) return Boolean
   is
   begin
      return DB.Connection.ConsumeInput;
   end Consume_Input;

   function Flush (DB : in Database'Class) return Boolean
   is
   begin
      return DB.Connection.Flush;
   end Flush;

   function  Is_Busy (DB : in Database'Class) return Boolean
   is
   begin
      return DB.Connection.IsBusy;
   end Is_Busy;

   function  Request_Cancel (DB : in Database'Class) return Boolean
   is
   begin
      return DB.Connection.RequestCancel;
   end Request_Cancel;

   function  Socket (DB : in Database'Class) return Interfaces.C.Int
   is
   begin
      return DB.Connection.Socket;
   end Socket;

   procedure Notifies (DB      : in  Database'Class;
                       Message : out Notification;
                       Done    : out Boolean)
   is
   begin
      DB.Connection.Notifies (Message, Done);
   end Notifies;

end GNU.DB.PostgreSQL;


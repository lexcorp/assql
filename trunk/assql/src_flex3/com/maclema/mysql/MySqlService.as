package com.maclema.mysql
{
	import com.maclema.mysql.events.MySqlErrorEvent;
	import com.maclema.mysql.events.MySqlEvent;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	
	import mx.collections.ArrayCollection;
	import mx.core.IMXMLObject;
	import mx.events.FlexEvent;
	import mx.rpc.IResponder;
	import mx.rpc.http.mxml.HTTPService;
	import mx.rpc.mxml.IMXMLSupport;
	
	[Event(name="sqlError", type="com.maclema.mysql.events.MySqlErrorEvent")]
	[Event(name="sql_response", type="com.maclema.mysql.events.MySqlEvent")]
	[Event(name="sql_result", type="com.maclema.mysql.events.MySqlEvent")]
	[Event(name="connect", type="flash.events.Event")]
	[Event(name="close", type="flash.events.Event")]
	public class MySqlService extends EventDispatcher
	{
		/**
		 * The hostname to connect to
		 **/
		public var hostname:String = "";
		
		/**
		 * The port to connect to
		 **/
		public var port:int = 3306;
		
		/**
		 * The username to authenticate with
		 **/
		public var username:String = "";
		
		/**
		 * The password to authenticate with
		 **/
		public var password:String = "";
		
		/**
		 * The database to switch to once connected
		 **/
		public var database:String = "";
		
		/**
		 * The responder to use for the mysql service
		 **/
		public var responder:IResponder;
		
		private var con:Connection;
		
		private var _lastResult:ArrayCollection;
		private var _lastResultSet:ResultSet;
		private var _connected:Boolean = false;
		
		private var _lastInsertID:int = -1;
		private var _lastAffectedRows:int = -1;
		
		public function MySqlService()
		{
		}
		
		/**
		 * Returns rows of the last ResultSet generated by a query.
		 **/
		[Bindable("lastResultChanged")]
		public function get lastResult():ArrayCollection {
			return _lastResult;
		}
		
		/**
		 * Returns the last ResultSet object generated by a query
		 **/
		[Bindable("lastResultChanged")]
		public function get lastResultSet():ResultSet {
			return _lastResultSet;
		}
		
		/**
		 * Returns the last insert id returned after a data manipulation query
		 **/
		[Bindable("lastResponseChanged")]
		public function get lastInsertID():int {
			return _lastInsertID;
		}
		
		/**
		 * Returns the number of affected rows returned after a data manipulation query
		 **/
		[Bindable("lastResponseChanged")]
		public function get lastAffectedRows():int {
			return _lastAffectedRows;
		}
		
		/**
		 * Returns the connection status
		 **/
		[Bindable("connectedChanged")]
		public function get connected():Boolean {
			return _connected;
		}
		
		/**
		 * Open the connection
		 **/
		public function connect():void {
			disconnect();
			
			con = new Connection(hostname, port, username, password, database);
			con.addEventListener(Event.CONNECT, handleConnected);
			con.addEventListener(Event.CLOSE, handleDisconnected);
			con.addEventListener(MySqlErrorEvent.SQL_ERROR, handleConnectError);
			con.connect();
		}
		
		/**
		 * Closes the connection
		 **/
		public function disconnect():void {
			if ( con != null ) {
				con.disconnect();
				con.removeEventListener(Event.CONNECT, handleConnected);
				con.removeEventListener(Event.CLOSE, handleDisconnected);
				con.removeEventListener(MySqlErrorEvent.SQL_ERROR, handleConnectError);
				con = null;
			}
		}
		
		private function handleConnected(e:Event):void {
			_connected = true;
			dispatchEvent(new Event("connectedChanged"));
			dispatchEvent(e);
		}
		
		private function handleDisconnected(e:Event):void {
			_connected = false;
			dispatchEvent(new Event("connectedChanged"));
			dispatchEvent(e);
		}
		
		private function handleConnectError(e:MySqlErrorEvent):void {
			dispatchEvent(e);
		}
		
		/**
		 * Executes a query, you may pass in either an sql string,
		 * or a BinaryQuery object.
		 **/
		public function send(queryObject:*):void {
			var st:Statement = con.createStatement();
			
			if ( queryObject is String ) {
				st.executeQuery(String(queryObject), new MySqlResponser( handleResult,handleError ));
			}
			else if ( queryObject is BinaryQuery ) {
				st.executeBinaryQuery(BinaryQuery(queryObject), new MySqlResponser( handleResult,handleError ));	
			}
		}
		
		private function handleResult(e:MySqlEvent):void {
			if ( e.type == MySqlEvent.RESULT ) {
				_lastResultSet = e.resultSet;
				_lastResult = _lastResultSet.getRows();
				dispatchEvent(new Event("lastResultChanged"));
			}
			else if ( e.type == MySqlEvent.RESPONSE ) {
				_lastInsertID = e.insertID;
				_lastAffectedRows = e.affectedRows;
				dispatchEvent(new Event("lastResponseChanged"));	
			}
			
			if ( responder != null ) {
				responder.result(e);
			}
			
			dispatchEvent(e);
		}
		
		private function handleError(e:MySqlErrorEvent):void {
			if ( responder != null ) {
				responder.fault(e);
			}
			
			dispatchEvent(e);
		}
	}
}
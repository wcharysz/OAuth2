//
//  OAuth2Loader.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 7/28/15.
//  Copyright 2015 Pascal Pfiffner
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation


/**
	A class to facilitate loading resources from an OAuth2 protected server.
 */
public class OAuth2Loader
{
	var oauth: OAuth2
	
	/// If true (the default), the loader intercepts 401s and attempts to refresh its token.
	public var tryAutorefresh = true
	
	var session: NSURLSession {
		if nil == _session {
			let config = NSURLSessionConfiguration.defaultSessionConfiguration()
			sessionDelegate = OAuth2SessionDelegate(loader: self)
			_session = NSURLSession(configuration: config, delegate: sessionDelegate, delegateQueue: nil)
		}
		return _session!
	}
	var _session: NSURLSession?
	
	var sessionDelegate: NSURLSessionTaskDelegate?
	
	var responseCallback: ((response: NSHTTPURLResponse?, data: NSData?, error: NSError?) -> Void)?
	
	public init(oauth: OAuth2) {
		self.oauth = oauth
	}
	
	
	// MARK: - Requests
	
	func performRequest(request: NSMutableURLRequest, callback: ((response: NSHTTPURLResponse?, data: NSData?, error: NSError?) -> Void)) {
		if nil != responseCallback {
//			PROBLEM: simultaneous requests!
			callback(response: nil, data: nil, error: nil)
			return
		}
		responseCallback = callback
		if let task = session.dataTaskWithRequest(request) {
			task.resume()
		}
	}
	
	public func requestDataFrom(url: NSURL, callback: ((data: NSData?, error: NSError?) -> Void)) {
		let req = oauth.request(forURL: url)
		performRequest(req) { response, data, error in
			if let error = error {
				if let code = response?.statusCode where 401 == code && self.tryAutorefresh {
					print("Got a 401, should try to refresh token")
					callback(data: data, error: error)
				}
				else {
					callback(data: data, error: error)
				}
			}
			else {
				callback(data: data, error: nil)
			}
		}
	}
	
	public func requestJSONFrom(url: NSURL, callback: ((json: [String: NSCoding]?, error: NSError?) -> Void)) {
		requestDataFrom(url) { data, error in
			if nil != error || nil == data {
				callback(json: nil, error: error)
			}
			else {
				do {
					let dict = try NSJSONSerialization.JSONObjectWithData(data!, options: []) as? [String: NSCoding]
					callback(json: dict, error: nil)
				}
				catch let error {
					callback(json: nil, error: error as NSError)
				}
			}
		}
	}
	
	func didReceiveResponse(response: NSHTTPURLResponse, data: NSData?, error: NSError?) {
		responseCallback?(response: response, data: data, error: error)
		responseCallback = nil
	}
}


public class OAuth2SessionDelegate: NSObject, NSURLSessionTaskDelegate, NSURLSessionDataDelegate
{
	let loader: OAuth2Loader
	
	var taskData: NSMutableData?
	
	public init(loader: OAuth2Loader) {
		self.loader = loader
	}
	
	public func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
		loader.didReceiveResponse(task.response as! NSHTTPURLResponse, data: taskData, error: error)
		taskData = nil
	}
	
	public func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
		taskData = taskData ?? NSMutableData()
		taskData?.appendData(data)
	}
}


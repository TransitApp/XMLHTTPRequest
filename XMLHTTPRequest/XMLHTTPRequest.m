#import "XMLHTTPRequest.h"


@implementation XMLHttpRequest {
    NSURLSession *_urlSession;
    NSString *_httpMethod;
    NSURL *_url;
    bool _async;
    NSMutableDictionary *_requestHeaders;
    NSDictionary *_responseHeaders;
    NSMutableDictionary<NSString *, JSValue *> *_eventListeners;
    NSMutableDictionary<NSString *, JSValue *> *_onreadystatechanges;
};

@synthesize response;
@synthesize responseText;
@synthesize responseType;
@synthesize onreadystatechange;
@synthesize readyState;
@synthesize onload;
@synthesize onerror;
@synthesize status;
@synthesize statusText;

static NSString * const kEventListenerErrorType = @"error";

- (instancetype)init {
    return [self initWithURLSession:[NSURLSession sharedSession]];
}


- (instancetype)initWithURLSession:(NSURLSession *)urlSession {
    if (self = [super init]) {
        _urlSession = urlSession;
        self.readyState = @(XMLHttpRequestUNSENT);
        _requestHeaders = [NSMutableDictionary new];
        _eventListeners = [NSMutableDictionary new];
        _onreadystatechanges = [NSMutableDictionary new];
    }
    return self;
}

- (void)extend:(id)jsContext {

    // Simulate the constructor.
    jsContext[@"XMLHttpRequest"] = ^{
        return self;
    };
    jsContext[@"XMLHttpRequest"][@"UNSENT"] = @(XMLHttpRequestUNSENT);
    jsContext[@"XMLHttpRequest"][@"OPENED"] = @(XMLHttpRequestOPENED);
    jsContext[@"XMLHttpRequest"][@"LOADING"] = @(XMLHttpRequestLOADING);
    jsContext[@"XMLHttpRequest"][@"HEADERS"] = @(XMLHttpRequestHEADERS);
    jsContext[@"XMLHttpRequest"][@"DONE"] = @(XMLHttpRequestDONE);
}

- (void)addEventListener:(NSString *)type :(JSValue *)listener :(BOOL)capture {
    [_eventListeners setObject:listener forKey:type];
}

- (void)open:(NSString *)httpMethod :(NSString *)url :(bool)async {
    // TODO should throw an error if called with wrong arguments
    _httpMethod = httpMethod;
    _url = [NSURL URLWithString:url];
    _async = async;
    self.readyState = @(XMLHttpRequestOPENED);
}

- (void)send:(id)data {
    NSString *uniqueId = [NSUUID new].UUIDString;
    _onreadystatechanges[uniqueId] = self.onreadystatechange;
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:_url];
    for (NSString *name in _requestHeaders) {
        [request setValue:_requestHeaders[name] forHTTPHeaderField:name];
    }
    if ([data isKindOfClass:[NSString class]]) {
        request.HTTPBody = [((NSString *) data) dataUsingEncoding:NSUTF8StringEncoding];
    }
    [request setHTTPMethod:_httpMethod];

    __block __weak XMLHttpRequest *weakSelf = self;
    __block __weak NSMutableDictionary<NSString *, JSValue *> *weakEventListeners = _eventListeners;

    id completionHandler = ^(NSData *receivedData, NSURLResponse *response, NSError *error) {
        if (error) {
            for (NSString *type in [weakEventListeners allKeys]) {
                if ([type isEqualToString:kEventListenerErrorType]) {
                    JSValue *function = [weakEventListeners objectForKey:type];
                    if (function) {
                        [function callWithArguments:@[[error localizedDescription]]];
                    }
                }
            }
        }
        else {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
            weakSelf.readyState = @(XMLHttpRequestDONE); // TODO
            weakSelf.status = @(httpResponse.statusCode);
            weakSelf.statusText = [NSString stringWithFormat:@"%ld",httpResponse.statusCode];
            weakSelf.responseText = [[NSString alloc] initWithData:receivedData
                                                          encoding:NSUTF8StringEncoding];

            weakSelf.responseType = @"";
            weakSelf.response = weakSelf.responseText;

            [weakSelf setAllResponseHeaders:[httpResponse allHeaderFields]];
            
            __strong __typeof (weakSelf) sself = weakSelf;
            JSValue *onreadystatechangeBlock = sself->_onreadystatechanges[uniqueId];
            if (onreadystatechangeBlock != nil) {
                [onreadystatechangeBlock callWithArguments:@[]];

                NSLog(@"=== RESPONSE ===============================");
                NSLog(@"Unique ID: %@", uniqueId);
                NSLog(@"Response URL: %@", httpResponse.URL);
                NSLog(@"Response Headers: %@", httpResponse.allHeaderFields);
                NSLog(@"Response Body: %@", [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding]);
                NSLog(@"============================================");

                [sself->_onreadystatechanges removeObjectForKey:uniqueId];
            }
        }
    };
    NSURLSessionDataTask *task = [_urlSession dataTaskWithRequest:request
                                                completionHandler:completionHandler];

    NSLog(@"=== REQUEST ================================");
    NSLog(@"Unique ID: %@", uniqueId);
    NSLog(@"Request URL: %@", request.URL);
    NSLog(@"Request Headers: %@", request.allHTTPHeaderFields);
    NSLog(@"Request Body: %@", request.HTTPBody);
    NSLog(@"============================================");


    [task resume];
}

- (void)setRequestHeader:(NSString *)name :(NSString *)value {
    _requestHeaders[name] = value;
}

- (NSString *)getAllResponseHeaders {
    NSMutableString *responseHeaders = [NSMutableString new];
    for (NSString *key in _responseHeaders) {
        [responseHeaders appendString:key];
        [responseHeaders appendString:@": "];
        [responseHeaders appendString:_responseHeaders[key]];
        [responseHeaders appendString:@"\r\n"];
    }
    return responseHeaders;
}

- (NSString *)getResponseHeader:(NSString *)name {
    return _responseHeaders[name];
}

- (void)setAllResponseHeaders:(NSDictionary *)responseHeaders {
    _responseHeaders = responseHeaders;
}

@end

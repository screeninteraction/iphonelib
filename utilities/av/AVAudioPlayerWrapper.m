/*
 Copyright (c) 2010, Sungjin Han <meinside@gmail.com>
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
  * Redistributions of source code must retain the above copyright notice,
    this list of conditions and the following disclaimer.
  * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.
  * Neither the name of meinside nor the names of its contributors may be
    used to endorse or promote products derived from this software without
    specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 */
//
//  AVAudioPlayerWrapper.m
//  iPhoneLib,
//  Helper Functions and Classes for Ordinary Application Development on iPhone
//
//  Created by meinside on 10. 08. 22.
//
//  last update: 10.09.07.
//

#import "AVAudioPlayerWrapper.h"

#import "FileUtil.h"

#import "Logging.h"


@implementation AVAudioPlayerWrapper

static AVAudioPlayerWrapper* _player;

- (void)playNextSound:(NSTimer*)timer
{
	@synchronized(self)
	{
		if([filenames count] <= 0)
		{
			DebugLog(@"nothing in the play queue");
			
			[delegate audioPlayerWrapper:self didFinishPlayingSuccessfully:NO];

			return;
		}
		
		NSString* filename = [filenames objectAtIndex:0];

		[lastPlayedFilename release];
		lastPlayedFilename = [filename copy];

		NSString* filepath = [FileUtil pathOfFile:filename withPathType:PathTypeResource];
		[filenames removeObjectAtIndex:0];
		
		[player release];
		player = nil;
		
		if(![FileUtil fileExistsAtPath:filepath])
		{
			DebugLog(@"given resource file does not exist: %@", filename);

			[delegate audioPlayerWrapper:self didFinishPlayingSuccessfully:NO];

			return;
		}

		[delegate audioPlayerWrapper:self willStartPlayingFilename:filename];
		
		NSError* error;
		player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:filepath] 
														error:&error];
		[player setDelegate:self];
		[player play];
		
		[delegate audioPlayerWrapper:self didStartPlayingFilename:filename];
	}
}

- (id)init
{
	if((self = [super init]))
	{
		//nothing to do

		DebugLog(@"AVAudioPlayerWrapper initialized");
	}
	return self;
}

+ (AVAudioPlayerWrapper*)sharedInstance
{
	@synchronized(self)
	{
		if(!_player)
		{
			_player = [[AVAudioPlayerWrapper alloc] init];
		}
	}
	return _player;
}

+ (void)disposeSharedInstance
{
	@synchronized(self)
	{
		[_player release];
		_player = nil;

		DebugLog(@"AVAudioPlayerWrapper disposed");
	}
}

- (BOOL)playSound:(NSString*)filename
{
	DebugLog(@"playing sound filename: %@", filename);

	[lastPlayedFilename release];
	lastPlayedFilename = [filename copy];

	NSString* filepath = [FileUtil pathOfFile:filename 
								 withPathType:PathTypeResource];
	
	if(![FileUtil fileExistsAtPath:filepath])
	{
		DebugLog(@"given resource file does not exist: %@", filename);
		return NO;
	}
	
	@synchronized(self)
	{
		if(playTimer)
		{
			[playTimer invalidate];
			[playTimer release];
			playTimer = nil;
		}
		
		[filenames release];
		filenames = nil;
		
		if(player)
		{
			[player stop];
			[player release];
			player = nil;
		}
		
		[delegate audioPlayerWrapper:self willStartPlayingFilename:filename];
		
		NSError* error;
		player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:filepath] 
														error:&error];
		[player setDelegate:self];
		[player play];
		
		[delegate audioPlayerWrapper:self didStartPlayingFilename:filename];
	}
	
	return YES;
}

- (void)playSounds:(NSArray*)someFilenames withGap:(float)someGap delay:(float)someDelay
{
	DebugLog(@"playing sound filenames: %@", someFilenames);

	@synchronized(self)
	{
		gap = someGap;
		
		if(playTimer)
		{
			[playTimer invalidate];
			[playTimer release];
			playTimer = nil;
		}
		
		[filenames release];
		filenames = nil;
		
		filenames = [[NSMutableArray arrayWithArray:someFilenames] retain];
		
		if(player)
		{
			[player stop];
			[player release];
			player = nil;
		}
		
		playTimer = [[NSTimer scheduledTimerWithTimeInterval:someDelay 
													  target:self 
													selector:@selector(playNextSound:) 
													userInfo:nil 
													 repeats:NO] retain];
	}
}

- (void)stopSound
{
	DebugLog(@"stopping sound: %@", lastPlayedFilename);

	@synchronized(self)
	{
		if(playTimer)
		{
			[playTimer invalidate];
			[playTimer release];
			playTimer = nil;
		}
		
		[filenames release];
		filenames = nil;
		
		if(player)
		{
			if([player isPlaying])
			{
				[player stop];

				[delegate audioPlayerWrapper:self didFinishPlayingFilename:lastPlayedFilename];
				[delegate audioPlayerWrapper:self didFinishPlayingSuccessfully:NO];
			}
			[player release];
			player = nil;
		}
	}
}

- (void)setDelegate:(id<AVAudioPlayerWrapperDelegate>)newDelegate
{
	[delegate release];
	delegate = [newDelegate retain];
}

- (void)dealloc
{
	[playTimer invalidate];
	[playTimer release];
	
	[player stop];
	[player release];
	
	[filenames release];
	
	[lastPlayedFilename release];
	
	[delegate release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark av audio player delegate functions

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)aPlayer successfully:(BOOL)flag
{
	if(flag)
	{
		[delegate audioPlayerWrapper:self didFinishPlayingFilename:lastPlayedFilename];

		@synchronized(self)
		{
			if([filenames count] > 0)
			{
				DebugLog(@"playing next sound");

				[playTimer invalidate];
				[playTimer release];
				playTimer = [[NSTimer scheduledTimerWithTimeInterval:gap 
															  target:self 
															selector:@selector(playNextSound:) 
															userInfo:nil 
															 repeats:NO] retain];
			}
			else
			{
				DebugLog(@"no more files left in the play queue");

				[delegate audioPlayerWrapper:self didFinishPlayingSuccessfully:YES];
			}
		}
	}
	else
	{
		DebugLog(@"did finish playing unsuccessfully");
		
		[delegate audioPlayerWrapper:self didFinishPlayingSuccessfully:NO];
	}
}

- (void)audioPlayerEndInterruption:(AVAudioPlayer *)aPlayer
{
	DebugLog(@"playing interrupted");

	//do what?
//	[delegate audioPlayerWrapper:self didFinishPlayingSuccessfully:YES];
}

@end
#import <moaiext-iphone/NSDictionary+MOAILib.h>
#import <moaiext-iphone/NSNumber+MOAILib.h>
#import <moaiext-iphone/NSObject+MOAILib.h>
#import <moaiext-iphone/NSString+MOAILib.h>

#import <objc/runtime.h>

//----------------------------------------------------------------//
void loadMoaiLib_NSObject () {
	// do nothing; force linker to load obj-c categories w/o needing linker flags
}

//================================================================//
// MOAILibDummyProtocol
//================================================================//
@protocol MOAILibDummyProtocol
@end

//================================================================//
// NSObject ( MOAILib )
//================================================================//
@implementation NSObject ( MOAILib )

	//----------------------------------------------------------------//
	-( id ) isOf:( id )base {
	
		id obj = self;
		id result = obj;

		const id dummyProtocol = @protocol ( MOAILibDummyProtocol );

		// check to see if base is a Protocol
		if ( object_getClass(base) == object_getClass(dummyProtocol) ) {
			if ([ obj conformsToProtocol:base ]) {
				return result;
			}
			return nil;
		}
		else {

			obj = [ obj class ];

			while ( obj ) {
				if ( obj == base ) return result;
				obj = [ obj superclass ];
			}
		}
		return nil;
	}

	//----------------------------------------------------------------//
	-( void ) performSelector :( SEL )selector afterDelay:( float )delay {
	
		[ self performSelector:selector withObject:nil afterDelay:delay ];
	}

	//----------------------------------------------------------------//
	-( void	) toLua:( lua_State* )state {

		lua_pushnil ( state );
	}

@end

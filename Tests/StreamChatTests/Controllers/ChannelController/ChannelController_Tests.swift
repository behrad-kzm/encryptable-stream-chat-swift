//
// Copyright © 2022 Stream.io Inc. All rights reserved.
//

import CoreData
@testable import StreamChat
@testable import StreamChatTestTools
import XCTest

final class ChannelController_Tests: XCTestCase {
    fileprivate var env: TestEnvironment!
    
    var client: ChatClient!
    
    var channelId: ChannelId!
    
    var controller: ChatChannelController!
    var controllerCallbackQueueID: UUID!
    /// Workaround for unwrapping **controllerCallbackQueueID!** in each closure that captures it
    private var callbackQueueID: UUID { controllerCallbackQueueID }
    
    override func setUp() {
        super.setUp()
        
        env = TestEnvironment()
        client = ChatClient.mock
        channelId = ChannelId.unique
        controller = ChatChannelController(
            channelQuery: .init(cid: channelId),
            channelListQuery: nil,
            client: client,
            environment: env.environment
        )
        controllerCallbackQueueID = UUID()
        controller.callbackQueue = .testQueue(withId: controllerCallbackQueueID)
    }
    
    override func tearDown() {
        env?.channelUpdater?.cleanUp()
        env?.eventSender?.cleanUp()

        AssertAsync {
            Assert.canBeReleased(&controller)
            Assert.canBeReleased(&client)
            Assert.canBeReleased(&env)
        }

        channelId = nil
        controllerCallbackQueueID = nil

        super.tearDown()
    }

    // MARK: - Init tests
    
    func test_init_assignsValuesCorrectly() {
        let channelQuery = ChannelQuery(cid: channelId)
        let channelListQuery = ChannelListQuery(filter: .containMembers(userIds: [.unique]))
        
        let controller = ChatChannelController(
            channelQuery: channelQuery,
            channelListQuery: channelListQuery,
            client: client
        )
        
        XCTAssertEqual(controller.channelQuery.cid, channelId)
        XCTAssertEqual(controller.channelListQuery, channelListQuery)
        XCTAssert(controller.client === client)
    }

    // MARK: - Channel
    
    func test_channel_accessible_initially() throws {
        let payload = dummyPayload(with: channelId)
        
        // Save two channels to DB (only one matching the query) and wait for completion
        try client.databaseContainer.writeSynchronously { session in
            // Channel with the id matching the query
            try session.saveChannel(payload: payload)
            // Other channel
            try session.saveChannel(payload: self.dummyPayload(with: .unique))
        }
        
        // Assert the channel and messages are loaded
        XCTAssertEqual(controller.channel?.cid, channelId)
        XCTAssertEqual(Set(controller.messages.map(\.id)), Set(payload.messages.map(\.id)))
    }

    // MARK: - Channel config feature tests
       
    func test_readFeatures_onNilChannel_returnsFalse() {
        XCTAssertFalse(controller.areReactionsEnabled)
        XCTAssertFalse(controller.areRepliesEnabled)
        XCTAssertFalse(controller.areQuotesEnabled)
        XCTAssertFalse(controller.areUploadsEnabled)
        XCTAssertFalse(controller.areTypingEventsEnabled)
        XCTAssertFalse(controller.areReadEventsEnabled)
    }

    func test_readAreReadEventsEnabled_whenTrue_returnsTrue() throws {
        let payload = dummyPayload(with: channelId, channelConfig: ChannelConfig(readEventsEnabled: true))
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: payload)
        }
        XCTAssertTrue(controller.areReadEventsEnabled)
    }
    
    func test_readAreReadEventsEnabled_whenFalse_returnsFalse() throws {
        let payload = dummyPayload(with: channelId, channelConfig: ChannelConfig(readEventsEnabled: false))
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: payload)
        }
        XCTAssertFalse(controller.areReadEventsEnabled)
    }
    
    func test_readAreTypingEventsEnabled_whenTrue_returnsTrue() throws {
        let payload = dummyPayload(with: channelId, channelConfig: ChannelConfig(typingEventsEnabled: true))
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: payload)
        }
        XCTAssertTrue(controller.areTypingEventsEnabled)
    }
    
    func test_readAreTypingEventsEnabled_whenFalse_returnsFalse() throws {
        let payload = dummyPayload(with: channelId, channelConfig: ChannelConfig(typingEventsEnabled: false))
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: payload)
        }
        XCTAssertFalse(controller.areTypingEventsEnabled)
    }
    
    func test_readAreReactionsEnabled_whenTrue_returnsTrue() throws {
        let payload = dummyPayload(with: channelId, channelConfig: ChannelConfig(reactionsEnabled: true))
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: payload)
        }
        XCTAssertTrue(controller.areReactionsEnabled)
    }
    
    func test_readAreReactionsEnabled_whenFalse_returnsFalse() throws {
        let payload = dummyPayload(with: channelId, channelConfig: ChannelConfig(reactionsEnabled: false))
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: payload)
        }
        XCTAssertFalse(controller.areReactionsEnabled)
    }
    
    func test_readAreRepliesEnabled_whenTrue_returnsTrue() throws {
        let payload = dummyPayload(with: channelId, channelConfig: ChannelConfig(repliesEnabled: true))
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: payload)
        }
        XCTAssertTrue(controller.areRepliesEnabled)
    }
    
    func test_readAreRepliesEnabled_whenFalse_returnsFalse() throws {
        let payload = dummyPayload(with: channelId, channelConfig: ChannelConfig(repliesEnabled: false))
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: payload)
        }
        XCTAssertFalse(controller.areRepliesEnabled)
    }
    
    func test_readAreQuotesEnabled_whenTrue_returnsTrue() throws {
        let payload = dummyPayload(with: channelId, channelConfig: ChannelConfig(quotesEnabled: true))
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: payload)
        }
        XCTAssertTrue(controller.areQuotesEnabled)
    }
    
    func test_readAreQuotesEnabled_whenFalse_returnsFalse() throws {
        let payload = dummyPayload(with: channelId, channelConfig: ChannelConfig(quotesEnabled: false))
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: payload)
        }
        XCTAssertFalse(controller.areQuotesEnabled)
    }
    
    func test_readAreUploadsEnabled_whenTrue_returnsTrue() throws {
        let payload = dummyPayload(with: channelId, channelConfig: ChannelConfig(uploadsEnabled: true))
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: payload)
        }
        XCTAssertTrue(controller.areUploadsEnabled)
    }
    
    func test_readAreUploadsEnabled_whenFalse_returnsFalse() throws {
        let payload = dummyPayload(with: channelId, channelConfig: ChannelConfig(uploadsEnabled: false))
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: payload)
        }
        XCTAssertFalse(controller.areUploadsEnabled)
    }
    
    // MARK: - Synchronize tests
    
    func test_synchronize_changesControllerState() throws {
        // Check if controller has initialized state initially.
        XCTAssertEqual(controller.state, .initialized)
        
        // Simulate `synchronize` call.
        controller.synchronize()
        
        // Save channel to database.
        try client.mockDatabaseContainer.createChannel(cid: channelId)
        
        // Simulate successful network call.
        env.channelUpdater?.update_completion?(.success(dummyPayload(with: .unique)))
        
        // Check if state changed after successful network call.
        AssertAsync.willBeEqual(controller.state, .remoteDataFetched)
    }
    
    func test_synchronize_changesControllerStateOnError() {
        // Check if controller has `initialized` state initially.
        assert(controller.state == .initialized)
        
        // Simulate `synchronize` call
        controller.synchronize()

        // Simulate failed network call.
        let error = TestError()
        env.channelUpdater?.update_completion?(.failure(error))
        
        // Check if state changed after failed network call.
        XCTAssertEqual(controller.state, .remoteDataFetchFailed(ClientError(with: error)))
    }
    
    func test_synchronize_callsChannelUpdater() throws {
        // Simulate `synchronize` calls and catch the completion
        var completionCalled = false
        controller.synchronize { [callbackQueueID] error in
            XCTAssertNil(error)
            AssertTestQueue(withId: callbackQueueID)
            completionCalled = true
        }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Assert the updater is called with the query
        XCTAssertEqual(env.channelUpdater!.update_channelQuery?.cid, channelId)
        // Completion shouldn't be called yet
        XCTAssertFalse(completionCalled)
        
        // Save channel to database.
        try client.mockDatabaseContainer.createChannel(cid: channelId)
        
        // Simulate successful update
        env.channelUpdater!.update_completion?(.success(dummyPayload(with: .unique)))
        // Release reference of completion so we can deallocate stuff
        env.channelUpdater!.update_completion = nil
        
        // Completion should be called
        AssertAsync.willBeTrue(completionCalled)
        // `weakController` should be deallocated too
        AssertAsync.canBeReleased(&weakController)
    }
    
    /// This test simulates a bug where the `channel` and `messages` fields were not updated if
    /// they weren't touched before calling synchronize.
    func test_fieldsAreFetched_evenAfterCallingSynchronize() throws {
        // Simulate synchronize call
        controller.synchronize()
        
        let payload = dummyPayload(with: channelId)
        assert(!payload.messages.isEmpty)
        
        // Simulate successful updater response
        try client.databaseContainer.writeSynchronously {
            try $0.saveChannel(payload: payload, query: nil, cache: nil)
        }
        env.channelUpdater?.update_completion?(.success(dummyPayload(with: .unique)))
        
        XCTAssertEqual(controller.channel?.cid, channelId)
        XCTAssertEqual(controller.messages.count, payload.messages.count)
    }

    /// This test simulates a bug where the `channel` and `messages` fields were not updated if
    /// they weren't touched before calling synchronize.
    func test_newChannelController_fieldsAreFetched_evenAfterCallingSynchronize() throws {
        setupControllerForNewChannel(query: .init(cid: channelId))
        
        // Simulate synchronize call
        controller.synchronize()
        
        let payload = dummyPayload(with: channelId)
        assert(!payload.messages.isEmpty)
        
        // Simulate successful updater response
        try client.databaseContainer.writeSynchronously {
            try $0.saveChannel(payload: payload, query: nil, cache: nil)
        }
        env.channelUpdater?.update_channelCreatedCallback?(channelId)
        env.channelUpdater?.update_completion?(.success(dummyPayload(with: .unique)))
        
        XCTAssertEqual(controller.channel?.cid, channelId)
        XCTAssertEqual(controller.messages.count, payload.messages.count)
    }

    /// This test simulates a bug where the `channel` and `messages` fields were not updated if
    /// they weren't touched before calling synchronize.
    func test_newMessageChannelController_fieldsAreFetched_evenAfterCallingSynchronize() throws {
        setupControllerForNewMessageChannel(cid: channelId)
        
        // Simulate synchronize call
        controller.synchronize()
        
        let payload = dummyPayload(with: channelId)
        assert(!payload.messages.isEmpty)
        
        // Simulate successful updater response
        try client.databaseContainer.writeSynchronously {
            try $0.saveChannel(payload: payload, query: nil, cache: nil)
        }
        env.channelUpdater?.update_channelCreatedCallback?(channelId)
        env.channelUpdater?.update_completion?(.success(dummyPayload(with: .unique)))
        
        XCTAssertEqual(controller.channel?.cid, channelId)
        XCTAssertEqual(controller.messages.count, payload.messages.count)
    }
    
    /// This test simulates a bug where the `channel` and `messages` fields were not updated if
    /// they weren't touched before calling synchronize.
    func test_newDMChannelController_fieldsAreFetched_evenAfterCallingSynchronize() throws {
        setupControllerForNewDirectMessageChannel(
            currentUserId: .unique,
            otherUserId: .unique
        )
        
        // Simulate synchronize call
        controller.synchronize()
        
        let payload = dummyPayload(with: channelId)
        assert(!payload.messages.isEmpty)
        
        // Simulate successful updater response
        try client.databaseContainer.writeSynchronously {
            try $0.saveChannel(payload: payload, query: nil, cache: nil)
        }
        
        // We call these callbacks on a queue other than main queue
        // to simulate the actual scenario where callbacks will be called
        // from NSURLSession-delegate (serial) queue
        let _: Bool = try waitFor { completion in
            DispatchQueue.global().async {
                self.env.channelUpdater?.update_channelCreatedCallback?(self.channelId)
                self.env.channelUpdater?.update_completion?(.success(self.dummyPayload(with: .unique)))
                completion(true)
            }
        }
        
        XCTAssertEqual(controller.channel?.cid, channelId)
        XCTAssertEqual(controller.messages.count, payload.messages.count)
    }

    func test_synchronize_propagesErrorFromUpdater() {
        // Simulate `synchronize` call and catch the completion
        var completionCalledError: Error?
        controller.synchronize { [callbackQueueID] in
            completionCalledError = $0
            AssertTestQueue(withId: callbackQueueID)
        }
        
        // Simulate failed update
        let testError = TestError()
        env.channelUpdater!.update_completion?(.failure(testError))
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
    }
    
    func test_failedMessageKeepsOrdering_whenLocalTimeIsNotSynced() throws {
        let userId: UserId = .unique
        let channelId: ChannelId = .unique
        
        // Create current user
        try client.databaseContainer.createCurrentUser(id: userId)
        
        // Setup controller
        setupControllerForNewMessageChannel(cid: channelId)
        
        // Save channel with some messages
        let channelPayload: ChannelPayload = dummyPayload(with: channelId, numberOfMessages: 5)
        let originalLastMessageAt: Date = channelPayload.channel.lastMessageAt ?? channelPayload.channel.createdAt
        try client.databaseContainer.writeSynchronously {
            try $0.saveChannel(payload: channelPayload)
        }
        
        // Get sorted messages (we'll use their createdAt later)
        let sortedMessages = channelPayload.messages.sorted(by: { $0.createdAt > $1.createdAt })
        
        // Create a new message payload that's older than `channel.lastMessageAt`
        // but newer than 2nd to last message
        let oldMessageCreatedAt = Date.unique(
            before: sortedMessages[0].createdAt,
            after: sortedMessages[1].createdAt
        )
        var oldMessageId: MessageId?
        // Save the message payload and check `channel.lastMessageAt` is not updated by older message
        try client.databaseContainer.writeSynchronously {
            let dto = try $0.createNewMessage(
                in: channelId,
                text: .unique,
                pinning: nil,
                command: nil,
                arguments: nil,
                parentMessageId: nil,
                attachments: [],
                mentionedUserIds: [],
                showReplyInChannel: false,
                isSilent: false,
                quotedMessageId: nil,
                createdAt: oldMessageCreatedAt,
                extraData: [:]
            )
            // Simulate sending failed for this message
            dto.localMessageState = .sendingFailed
            oldMessageId = dto.id
        }
        var channel = try XCTUnwrap(client.databaseContainer.viewContext.channel(cid: channelId))
        XCTAssertNearlySameDate(channel.lastMessageAt?.bridgeDate, originalLastMessageAt)

        // Create a new message payload that's newer than `channel.lastMessageAt`
        let newerMessagePayload: MessagePayload = .dummy(
            messageId: .unique,
            authorUserId: userId,
            createdAt: .unique(after: channelPayload.channel.lastMessageAt!)
        )
        // Save the message payload and check `channel.lastMessageAt` is updated
        try client.databaseContainer.writeSynchronously {
            try $0.saveMessage(payload: newerMessagePayload, for: channelId, syncOwnReactions: true, cache: nil)
        }
        channel = try XCTUnwrap(client.databaseContainer.viewContext.channel(cid: channelId))
        XCTAssertEqual(channel.lastMessageAt?.bridgeDate, newerMessagePayload.createdAt)
        
        // Check if the message ordering is correct
        // First message should be the newest message
        XCTAssertEqual(controller.messages[0].id, newerMessagePayload.id)
        // Third message is the failed one
        XCTAssertEqual(controller.messages[2].id, oldMessageId)
    }

    // MARK: - Creating `ChannelController` tests

    func test_channelControllerForNewChannel_createdCorrectly() throws {
        // Simulate currently logged-in user
        let currentUserId: UserId = .unique
        client.currentUserId = currentUserId

        let cid: ChannelId = .unique
        let team: String = .unique
        let members: Set<UserId> = [.unique]
        let invites: Set<UserId> = [.unique]

        // Create a new `ChannelController`
        for isCurrentUserMember in [true, false] {
            let controller = try client.channelController(
                createChannelWithId: cid,
                name: .unique,
                imageURL: .unique(),
                team: team,
                members: members,
                isCurrentUserMember: isCurrentUserMember,
                invites: invites,
                extraData: [:]
            )

            // Assert `ChannelQuery` created correctly
            XCTAssertEqual(cid, controller.channelQuery.cid)
            XCTAssertEqual(team, controller.channelQuery.channelPayload?.team)
            XCTAssertEqual(
                members.union(isCurrentUserMember ? [currentUserId] : []),
                controller.channelQuery.channelPayload?.members
            )
            XCTAssertEqual(invites, controller.channelQuery.channelPayload?.invites)
            XCTAssertEqual([:], controller.channelQuery.channelPayload?.extraData)
        }
    }

    func test_channelControllerForNewChannel_throwsError_ifCurrentUserDoesNotExist() throws {
        AssertAsync {
            Assert.canBeReleased(&controller)
            Assert.canBeReleased(&client)
            Assert.canBeReleased(&env)
        }
        
        let clientWithoutCurrentUser = ChatClient(config: .init(apiKeyString: .unique))

        for isCurrentUserMember in [true, false] {
            // Try to create `ChannelController` while current user is missing
            XCTAssertThrowsError(
                try clientWithoutCurrentUser.channelController(
                    createChannelWithId: .unique,
                    name: .unique,
                    imageURL: .unique(),
                    team: .unique,
                    members: [.unique, .unique],
                    isCurrentUserMember: isCurrentUserMember,
                    invites: [.unique, .unique],
                    extraData: [:]
                )
            ) { error in
                // Assert `ClientError.CurrentUserDoesNotExist` is thrown
                XCTAssertTrue(error is ClientError.CurrentUserDoesNotExist)
            }
        }
    }

    func test_channelControllerForNewChannel_includesCurrentUser_byDefault() throws {
        // Simulate currently logged-in user
        let currentUserId: UserId = .unique
        client.currentUserId = currentUserId

        // Create DM channel members.
        let members: Set<UserId> = [.unique, .unique, .unique]

        // Try to create `ChannelController` with non-empty members while current user is missing
        let controller = try client.channelController(
            createChannelWithId: .unique,
            name: .unique,
            imageURL: .unique(),
            team: .unique,
            members: members,
            extraData: [:]
        )

        XCTAssertEqual(controller.channelQuery.channelPayload?.members, members.union([currentUserId]))
    }

    func test_channelControllerForNew1on1Channel_createdCorrectly() throws {
        // Simulate currently logged-in user
        let currentUserId: UserId = .unique
        client.currentUserId = currentUserId

        for isCurrentUserMember in [true, false] {
            let team: String = .unique
            let members: Set<UserId> = [.unique]
            let channelType: ChannelType = .custom(.unique)

            // Create a new `ChannelController`
            let controller = try client.channelController(
                createDirectMessageChannelWith: members,
                type: channelType,
                isCurrentUserMember: isCurrentUserMember,
                name: .unique,
                imageURL: .unique(),
                team: team,
                extraData: [:]
            )

            // Assert `ChannelQuery` created correctly
            XCTAssertEqual(controller.channelQuery.channelPayload?.team, team)
            XCTAssertEqual(controller.channelQuery.type, channelType)
            XCTAssertEqual(
                members.union(isCurrentUserMember ? [currentUserId] : []),
                controller.channelQuery.channelPayload?.members
            )
            XCTAssertEqual(controller.channelQuery.channelPayload?.extraData, [:])
        }
    }

    func test_channelControllerForNew1on1Channel_throwsError_OnEmptyMembers() {
        // Simulate currently logged-in user
        let currentUserId: UserId = .unique
        client.currentUserId = currentUserId

        let members: Set<UserId> = []

        // Create a new `ChannelController`
        do {
            _ = try client.channelController(
                createDirectMessageChannelWith: members,
                name: .unique,
                imageURL: .unique(),
                team: .unique,
                extraData: .init()
            )
        } catch {
            XCTAssert(error is ClientError.ChannelEmptyMembers)
        }
    }

    func test_channelControllerForNewDirectMessagesChannel_throwsError_ifCurrentUserDoesNotExist() {
        AssertAsync {
            Assert.canBeReleased(&controller)
            Assert.canBeReleased(&self.client)
            Assert.canBeReleased(&env)
        }
        
        let client = ChatClient(config: .init(apiKeyString: .unique))

        for isCurrentUserMember in [true, false] {
            // Try to create `ChannelController` with non-empty members while current user is missing
            XCTAssertThrowsError(
                try client.channelController(
                    createDirectMessageChannelWith: [.unique],
                    isCurrentUserMember: isCurrentUserMember,
                    name: .unique,
                    imageURL: .unique(),
                    team: .unique,
                    extraData: .init()
                )
            ) { error in
                // Assert `ClientError.CurrentUserDoesNotExist` is thrown
                XCTAssertTrue(error is ClientError.CurrentUserDoesNotExist)
            }
        }
    }

    func test_channelControllerForNewDirectMessagesChannel_includesCurrentUser_byDefault() throws {
        // Simulate currently logged-in user
        let currentUserId: UserId = .unique
        client.currentUserId = currentUserId

        // Create DM channel members.
        let members: Set<UserId> = [.unique, .unique, .unique]

        // Try to create `ChannelController` with non-empty members while current user is missing
        let controller = try client.channelController(
            createDirectMessageChannelWith: members,
            name: .unique,
            imageURL: .unique(),
            team: .unique,
            extraData: .init()
        )

        XCTAssertEqual(controller.channelQuery.channelPayload?.members, members.union([currentUserId]))
    }
    
    func test_channelController_returnsNilCID_forNewDirectMessageChannel() throws {
        // Simulate currently logged-in user
        let currentUserId: UserId = .unique
        client.currentUserId = currentUserId

        // Create ChatChannelController for new channel
        controller = try client.channelController(
            createDirectMessageChannelWith: [.unique],
            name: .unique,
            imageURL: .unique(),
            extraData: [:]
        )
        
        // Assert cid is nil
        XCTAssertNil(controller.cid)
    }
    
    // MARK: - Channel change propagation tests
    
    func test_channelChanges_arePropagated() throws {
        // Simulate changes in the DB:
        _ = try waitFor {
            client.databaseContainer.write({ session in
                try session.saveChannel(payload: self.dummyPayload(with: self.channelId), query: nil, cache: nil)
            }, completion: $0)
        }
        
        // Assert the resulting value is updated
        AssertAsync.willBeEqual(controller.channel?.cid, channelId)
        AssertAsync.willBeTrue(controller.channel?.isFrozen)
        
        // Simulate channel changes
        _ = try waitFor {
            client.databaseContainer.write({ session in
                let context = (session as! NSManagedObjectContext)
                let channelDTO = try! context.fetch(ChannelDTO.fetchRequest(for: self.channelId)).first!
                channelDTO.isFrozen = false
            }, completion: $0)
        }
        
        AssertAsync.willBeTrue(controller.channel?.isFrozen == false)
    }
    
    func test_messageChanges_arePropagated() throws {
        let payload = dummyPayload(with: channelId)
        
        // Simulate changes in the DB:
        _ = try waitFor {
            client.databaseContainer.write({ session in
                try session.saveChannel(payload: payload)
            }, completion: $0)
        }
        
        // Simulate `synchronize` call
        controller.synchronize()
        
        // Simulate an incoming message
        let newMessageId: MessageId = .unique
        let newMessagePayload: MessagePayload = .dummy(
            messageId: newMessageId,
            authorUserId: .unique,
            createdAt: Date()
        )
        _ = try waitFor {
            client.databaseContainer.write({ session in
                try session.saveMessage(payload: newMessagePayload, for: self.channelId, syncOwnReactions: true, cache: nil)
            }, completion: $0)
        }
        
        // Assert the new message is presented
        AssertAsync.willBeTrue(controller.messages.contains { $0.id == newMessageId })
    }

    func test_messagesOrdering_topToBottom_HaveCorrectOrder() throws {
        // Create a channel
        try client.databaseContainer.createChannel(
            cid: channelId,
            withMessages: false
        )
        
        controller = client.channelController(
            for: channelId,
            messageOrdering: .topToBottom
        )
        
        // Insert two messages
        let message1: MessagePayload = .dummy(messageId: .unique, authorUserId: .unique)
        let message2: MessagePayload = .dummy(messageId: .unique, authorUserId: .unique)
        
        try client.databaseContainer.writeSynchronously {
            try $0.saveMessage(payload: message1, for: self.channelId, syncOwnReactions: true, cache: nil)
            try $0.saveMessage(payload: message2, for: self.channelId, syncOwnReactions: true, cache: nil)
        }
        
        // Check the order of messages is correct
        let topToBottomIds = [message1, message2].sorted { $0.createdAt > $1.createdAt }.map(\.id)
        XCTAssertEqual(controller.messages.map(\.id), topToBottomIds)
    }
    
    func test_messagesOrdering_bottomToTop_HaveCorrectOrder() throws {
        // Create a channel
        try client.databaseContainer.createChannel(
            cid: channelId,
            withMessages: false
        )
        
        controller = client.channelController(
            for: channelId,
            messageOrdering: .bottomToTop
        )
        
        // Insert two messages
        let message1: MessagePayload = .dummy(messageId: .unique, authorUserId: .unique)
        let message2: MessagePayload = .dummy(messageId: .unique, authorUserId: .unique)
        
        try client.databaseContainer.writeSynchronously {
            try $0.saveMessage(payload: message1, for: self.channelId, syncOwnReactions: true, cache: nil)
            try $0.saveMessage(payload: message2, for: self.channelId, syncOwnReactions: true, cache: nil)
        }
        
        // Check the order of messages is correct
        let bottomToTopIds = [message1, message2].sorted { $0.createdAt < $1.createdAt }.map(\.id)
        XCTAssertEqual(controller.messages.map(\.id), bottomToTopIds)
    }
    
    func test_threadReplies_areNotShownInChannel() throws {
        // Create a channel
        try client.databaseContainer.createChannel(cid: channelId, withMessages: false)
        controller = client.channelController(
            for: channelId,
            messageOrdering: .topToBottom
        )
        
        // Insert two messages
        let message1: MessagePayload = .dummy(messageId: "msg1-" + .unique, authorUserId: .unique)
        let message2: MessagePayload = .dummy(messageId: "msg2-" + .unique, authorUserId: .unique)
        
        // Insert reply that should be shown in channel.
        let reply1: MessagePayload = .dummy(
            messageId: "reply1-" + .unique,
            parentId: message2.id,
            showReplyInChannel: true,
            authorUserId: .unique
        )
        
        // Insert reply that should be visible only in thread.
        let reply2: MessagePayload = .dummy(
            messageId: "reply2-" + .unique,
            parentId: message2.id,
            showReplyInChannel: false,
            authorUserId: .unique
        )
        
        try client.databaseContainer.writeSynchronously {
            try $0.saveMessage(payload: message1, for: self.channelId, syncOwnReactions: true, cache: nil)
            try $0.saveMessage(payload: message2, for: self.channelId, syncOwnReactions: true, cache: nil)
            try $0.saveMessage(payload: reply1, for: self.channelId, syncOwnReactions: true, cache: nil)
            try $0.saveMessage(payload: reply2, for: self.channelId, syncOwnReactions: true, cache: nil)
        }
        
        // Check the relevant reply is shown in channel
        let messagesWithReply = [message1, message2, reply1].sorted { $0.createdAt > $1.createdAt }.map(\.id)
        XCTAssertEqual(controller.messages.map(\.id), messagesWithReply)
    }
    
    func test_threadEphemeralMessages_areNotShownInChannel() throws {
        // Create a channel
        try client.databaseContainer.createChannel(cid: channelId, withMessages: false)
        controller = client.channelController(
            for: channelId,
            messageOrdering: .topToBottom
        )
        
        // Insert a message
        let message1: MessagePayload = .dummy(messageId: .unique, authorUserId: .unique)
        
        // Insert ephemeral message in message1's thread
        let ephemeralMessage: MessagePayload = .dummy(
            type: .ephemeral,
            messageId: .unique,
            parentId: message1.id,
            authorUserId: .unique
        )
        
        try client.databaseContainer.writeSynchronously {
            try $0.saveMessage(payload: message1, for: self.channelId, syncOwnReactions: true, cache: nil)
            try $0.saveMessage(payload: ephemeralMessage, for: self.channelId, syncOwnReactions: true, cache: nil)
        }
        
        // Check the relevant ephemeral message is not shown in channel
        XCTAssertEqual(controller.messages.map(\.id), [message1].map(\.id))
    }

    func test_deletedMessages_withVisibleForCurrentUser_messageVisibility() throws {
        // Simulate the config setting
        client.databaseContainer.viewContext.deletedMessagesVisibility = .visibleForCurrentUser

        let currentUserID: UserId = .unique

        // Create current user
        try client.databaseContainer.createCurrentUser(id: currentUserID)

        // Create a channel
        try client.databaseContainer.createChannel(cid: channelId, withMessages: false)

        // Create incoming deleted message
        let incomingDeletedMessage: MessagePayload = .dummy(
            messageId: .unique,
            authorUserId: .unique,
            deletedAt: .unique
        )

        // Create outgoing deleted message
        let outgoingDeletedMessage: MessagePayload = .dummy(
            messageId: .unique,
            authorUserId: currentUserID,
            deletedAt: .unique
        )

        try client.databaseContainer.writeSynchronously {
            try $0.saveMessage(payload: incomingDeletedMessage, for: self.channelId, syncOwnReactions: true, cache: nil)
            try $0.saveMessage(payload: outgoingDeletedMessage, for: self.channelId, syncOwnReactions: true, cache: nil)
        }

        // Only outgoing deleted messages are returned by controller
        XCTAssertEqual(controller.messages.map(\.id), [outgoingDeletedMessage.id])
    }

    func test_deletedMessages_withAlwaysHidden_messageVisibility() throws {
        // Simulate the config setting
        client.databaseContainer.viewContext.deletedMessagesVisibility = .alwaysHidden

        let currentUserID: UserId = .unique

        // Create current user
        try client.databaseContainer.createCurrentUser(id: currentUserID)

        // Create a channel
        try client.databaseContainer.createChannel(cid: channelId, withMessages: false)

        // Create incoming deleted message
        let incomingDeletedMessage: MessagePayload = .dummy(
            messageId: .unique,
            authorUserId: .unique,
            deletedAt: .unique
        )

        // Create outgoing deleted message
        let outgoingDeletedMessage: MessagePayload = .dummy(
            messageId: .unique,
            authorUserId: currentUserID,
            deletedAt: .unique
        )

        try client.databaseContainer.writeSynchronously {
            try $0.saveMessage(payload: incomingDeletedMessage, for: self.channelId, syncOwnReactions: true, cache: nil)
            try $0.saveMessage(payload: outgoingDeletedMessage, for: self.channelId, syncOwnReactions: true, cache: nil)
        }

        // Both outgoing and incoming messages should NOT be visible
        XCTAssertTrue(controller.messages.isEmpty)
    }

    func test_deletedMessages_withAlwaysVisible_messageVisibility() throws {
        // Simulate the config setting
        client.databaseContainer.viewContext.deletedMessagesVisibility = .alwaysVisible

        let currentUserID: UserId = .unique

        // Create current user
        try client.databaseContainer.createCurrentUser(id: currentUserID)

        // Create a channel
        try client.databaseContainer.createChannel(cid: channelId, withMessages: false)

        // Create incoming deleted message
        let incomingDeletedMessage: MessagePayload = .dummy(
            messageId: .unique,
            authorUserId: .unique,
            deletedAt: .unique
        )

        // Create outgoing deleted message
        let outgoingDeletedMessage: MessagePayload = .dummy(
            messageId: .unique,
            authorUserId: currentUserID,
            deletedAt: .unique
        )

        try client.databaseContainer.writeSynchronously {
            try $0.saveMessage(payload: incomingDeletedMessage, for: self.channelId, syncOwnReactions: true, cache: nil)
            try $0.saveMessage(payload: outgoingDeletedMessage, for: self.channelId, syncOwnReactions: true, cache: nil)
        }

        // Both outgoing and incoming messages should be visible
        XCTAssertEqual(Set(controller.messages.map(\.id)), Set([outgoingDeletedMessage.id, incomingDeletedMessage.id]))
    }
    
    func test_shadowedMessages_whenVisible() throws {
        // Simulate the config setting
        client.databaseContainer.viewContext.shouldShowShadowedMessages = true
        
        let currentUserID: UserId = .unique
        
        // Create current user
        try client.databaseContainer.createCurrentUser(id: currentUserID)
        
        // Create a channel
        try client.databaseContainer.createChannel(cid: channelId, withMessages: false)
        
        // Create incoming shadowed message
        let shadowedMessage: MessagePayload = .dummy(
            messageId: .unique,
            authorUserId: .unique,
            isShadowed: true
        )
        
        // Create incoming non-shadowed message
        let nonShadowedMessage: MessagePayload = .dummy(
            messageId: .unique,
            authorUserId: .unique,
            isShadowed: false
        )
        
        try client.databaseContainer.writeSynchronously {
            try $0.saveMessage(payload: shadowedMessage, for: self.channelId, syncOwnReactions: true, cache: nil)
            try $0.saveMessage(payload: nonShadowedMessage, for: self.channelId, syncOwnReactions: true, cache: nil)
        }
        
        // Both messages should be visible
        XCTAssertEqual(Set(controller.messages.map(\.id)), Set([nonShadowedMessage.id, shadowedMessage.id]))
    }
    
    func test_shadowedMessages_defaultBehavior_isToHide() throws {
        let currentUserID: UserId = .unique
        
        // Create current user
        try client.databaseContainer.createCurrentUser(id: currentUserID)
        
        // Create a channel
        try client.databaseContainer.createChannel(cid: channelId, withMessages: false)
        
        // Create incoming shadowed message
        let shadowedMessage: MessagePayload = .dummy(
            messageId: .unique,
            authorUserId: .unique,
            isShadowed: true
        )
        
        // Create incoming non-shadowed message
        let nonShadowedMessage: MessagePayload = .dummy(
            messageId: .unique,
            authorUserId: .unique,
            isShadowed: false
        )
        
        try client.databaseContainer.writeSynchronously {
            try $0.saveMessage(payload: shadowedMessage, for: self.channelId, syncOwnReactions: true, cache: nil)
            try $0.saveMessage(payload: nonShadowedMessage, for: self.channelId, syncOwnReactions: true, cache: nil)
        }
        
        // Only non-shadowed message should be visible
        XCTAssertEqual(Set(controller.messages.map(\.id)), Set([nonShadowedMessage.id]))
    }

    // MARK: - Delegate tests
    
    func test_settingDelegate_leadsToFetchingLocalData() {
        let delegate = ChannelController_Delegate(expectedQueueId: controllerCallbackQueueID)
           
        // Check initial state
        XCTAssertEqual(controller.state, .initialized)
           
        controller.delegate = delegate
           
        // Assert state changed
        AssertAsync.willBeEqual(controller.state, .localDataFetched)
    }
    
    func test_delegate_isNotifiedAboutStateChanges() throws {
        // Set the delegate
        let delegate = ChannelController_Delegate(expectedQueueId: controllerCallbackQueueID)
        controller.delegate = delegate
        
        // Assert delegate is notified about state changes
        AssertAsync.willBeEqual(delegate.state, .localDataFetched)

        // Synchronize
        controller.synchronize()
            
        // Save channel to database.
        try client.mockDatabaseContainer.createChannel(cid: channelId)
        
        // Simulate network call response
        env.channelUpdater?.update_completion?(.success(dummyPayload(with: .unique)))
        
        // Assert delegate is notified about state changes
        AssertAsync.willBeEqual(delegate.state, .remoteDataFetched)
    }

    func test_delegateContinueToReceiveEvents_afterObserversReset() throws {
        // Assign `ChannelController` that creates new channel
        controller = ChatChannelController(
            channelQuery: ChannelQuery(cid: channelId),
            channelListQuery: nil,
            client: client,
            environment: env.environment,
            isChannelAlreadyCreated: false
        )
        controller.callbackQueue = .testQueue(withId: controllerCallbackQueueID)

        // Setup delegate
        let delegate = ChannelController_Delegate(expectedQueueId: controllerCallbackQueueID)
        controller.delegate = delegate

        // Simulate `synchronize` call
        controller.synchronize()
        
        // Simulate updater's channelCreatedCallback call
        env.channelUpdater!.update_channelCreatedCallback!(channelId)

        // Simulate DB update
        var error = try waitFor {
            client.databaseContainer.write({ session in
                try session.saveChannel(payload: self.dummyPayload(with: self.channelId), query: nil, cache: nil)
            }, completion: $0)
        }
        XCTAssertNil(error)
        let channel = try XCTUnwrap(client.databaseContainer.viewContext.channel(cid: channelId)).asModel()
        XCTAssertEqual(channel.latestMessages.count, 1)
        let message: ChatMessage = try XCTUnwrap(channel.latestMessages.first)

        // Assert DB observers call delegate updates
        AssertAsync {
            Assert.willBeEqual(delegate.didUpdateChannel_channel, .create(channel))
            Assert.willBeEqual(delegate.didUpdateMessages_messages, [.insert(message, index: [0, 0])])
        }

        let newCid: ChannelId = .unique

        // Simulate `channelCreatedCallback` call that will reset DB observers to observing data with new `cid`
        env.channelUpdater!.update_channelCreatedCallback?(newCid)

        // Simulate DB update
        error = try waitFor {
            client.databaseContainer.write({ session in
                try session.saveChannel(payload: self.dummyPayload(with: newCid), query: nil, cache: nil)
            }, completion: $0)
        }
        XCTAssertNil(error)
        let newChannel = try XCTUnwrap(client.databaseContainer.viewContext.channel(cid: newCid)).asModel()
        assert(channel.latestMessages.count == 1)
        let newMessage: ChatMessage = newChannel.latestMessages.first!

        // Assert DB observers call delegate updates for new `cid`
        AssertAsync {
            Assert.willBeEqual(delegate.didUpdateChannel_channel, .create(newChannel))
            Assert.willBeEqual(delegate.didUpdateMessages_messages, [.insert(newMessage, index: [0, 0])])
        }
    }
    
    func test_channelMemberEvents_areForwardedToDelegate() throws {
        let delegate = ChannelController_Delegate(expectedQueueId: controllerCallbackQueueID)
        controller.delegate = delegate
        
        // Simulate `synchronize()` call
        controller.synchronize()
        
        // Send notification with event happened in the observed channel
        let event = TestMemberEvent(cid: controller.channelQuery.cid!, memberUserId: .unique)
        let notification = Notification(newEventReceived: event, sender: self)
        client.webSocketClient!.eventNotificationCenter.post(notification)
        
        // Assert the event is received
        AssertAsync.willBeEqual(delegate.didReceiveMemberEvent_event as? TestMemberEvent, event)
    }
    
    func test_channelTypingEvents_areForwardedToDelegate() throws {
        let userId: UserId = .unique
        // Create channel in the database
        try client.databaseContainer.createChannel(cid: channelId)
        // Create user in the database
        try client.databaseContainer.createUser(id: userId)
        
        // Set the queue for delegate calls
        let delegate = ChannelController_Delegate(expectedQueueId: controllerCallbackQueueID)
        controller.delegate = delegate
        
        // Simulate `synchronize()` call
        controller.synchronize()

        // Save user as a typing member
        try client.databaseContainer.writeSynchronously { session in
            let channel = try XCTUnwrap(session.channel(cid: self.channelId))
            let user = try XCTUnwrap(session.user(id: userId))
            channel.currentlyTypingUsers.insert(user)
        }
        
        // Load the user
        let typingUser = try XCTUnwrap(client.databaseContainer.viewContext.user(id: userId)).asModel()

        // Assert the delegate receives typing user
        AssertAsync.willBeEqual(delegate.didChangeTypingUsers_typingUsers, [typingUser])
    }
    
    func test_delegateMethodsAreCalled() throws {
        let delegate = ChannelController_Delegate(expectedQueueId: controllerCallbackQueueID)
        controller.delegate = delegate
        
        // Assert the delegate is assigned correctly. We should test this because of the type-erasing we
        // do in the controller.
        XCTAssert(controller.delegate === delegate)
        
        // Simulate `synchronize()` call
        controller.synchronize()
        
        // Simulate DB update
        let error = try waitFor {
            client.databaseContainer.write({ session in
                try session.saveChannel(payload: self.dummyPayload(with: self.channelId), query: nil, cache: nil)
            }, completion: $0)
        }
        XCTAssertNil(error)
        let channel = try XCTUnwrap(client.databaseContainer.viewContext.channel(cid: channelId)).asModel()
        XCTAssertEqual(channel.latestMessages.count, 1)
        let message: ChatMessage = try XCTUnwrap(channel.latestMessages.first)
        
        AssertAsync {
            Assert.willBeEqual(delegate.didUpdateChannel_channel, .create(channel))
            Assert.willBeEqual(delegate.didUpdateMessages_messages, [.insert(message, index: [0, 0])])
        }
    }
    
    func test_channelUpdateDelegate_isCalled_whenChannelReadsAreUpdated() throws {
        let delegate = ChannelController_Delegate(expectedQueueId: controllerCallbackQueueID)
        controller.delegate = delegate
        
        let userId: UserId = .unique
        
        let originalReadDate: Date = .unique
        
        // Create a channel in the DB
        try client.databaseContainer.writeSynchronously {
            try $0.saveChannel(payload: self.dummyPayload(with: self.channelId), query: nil, cache: nil)
            // Create a read for the channel
            try $0.saveChannelRead(
                payload: ChannelReadPayload(
                    user: self.dummyUser(id: userId),
                    lastReadAt: originalReadDate,
                    unreadMessagesCount: .unique // This value doesn't matter at all. It's not updated by events. We cam ignore it.
                ),
                for: self.channelId,
                cache: nil
            )
        }
        
        XCTAssertEqual(
            controller.channel?.reads.first(where: { $0.user.id == userId })?.lastReadAt,
            originalReadDate
        )
        
        // Simulate `synchronize()` call
        controller.synchronize()
        
        let newReadDate: Date = .unique
        
        // Update the read
        try client.databaseContainer.writeSynchronously {
            let read = try XCTUnwrap($0.loadChannelRead(cid: self.channelId, userId: userId))
            read.lastReadAt = newReadDate.bridgeDate
        }

        // Assert the value is updated and the delegate is called
        XCTAssertEqual(
            controller.channel?.reads.first(where: { $0.user.id == userId })?.lastReadAt,
            newReadDate
        )
        
        AssertAsync.willBeEqual(delegate.didUpdateChannel_channel, .update(controller.channel!))
    }
    
    // MARK: - New direct message channel creation tests
    
    func test_controller_reportsInitialValues_forDMChannel_ifChannelDoesntExistLocally() throws {
        // Create mock users
        let currentUserId = UserId.unique
        let otherUserId = UserId.unique
        
        // Create controller for the non-existent new DM channel
        setupControllerForNewDirectMessageChannel(currentUserId: currentUserId, otherUserId: otherUserId)
        
        // Create and set delegate
        let delegate = ChannelController_Delegate(expectedQueueId: controllerCallbackQueueID)
        controller.delegate = delegate
        
        // Simulate synchronize
        controller.synchronize()
        
        // Create dummy channel with messages
        let dummyChannel = dummyPayload(
            with: .unique,
            numberOfMessages: 10,
            members: [
                .dummy(user: .dummy(userId: currentUserId)),
                .dummy(user: .dummy(userId: otherUserId))
            ]
        )
        
        // Simulate successful backend channel creation
        env.channelUpdater!.update_channelCreatedCallback?(dummyChannel.channel.cid)
        
        // Simulate new channel creation in DB
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: dummyChannel)
        }
        
        // Simulate successful network call
        env.channelUpdater!.update_completion?(.success(dummyPayload(with: .unique)))
        
        // Assert that initial reported values are correct
        XCTAssertEqual(controller.channel?.cid, dummyChannel.channel.cid)
        XCTAssertEqual(controller.messages.count, dummyChannel.messages.count)
        
        // Assert the delegate is called for initial values
        XCTAssertEqual(delegate.didUpdateChannel_channel?.item.cid, dummyChannel.channel.cid)
        XCTAssertEqual(delegate.didUpdateMessages_messages?.count, dummyChannel.messages.count)
    }
    
    func test_controller_reportsInitialValues_forDMChannel_ifChannelExistsLocally() throws {
        // Create mock users
        let currentUserId = UserId.unique
        let otherUserId = UserId.unique
        
        // Create dummy channel with messages
        let dummyChannel = dummyPayload(
            with: .unique,
            numberOfMessages: 10,
            members: [
                .dummy(user: .dummy(userId: currentUserId)),
                .dummy(user: .dummy(userId: otherUserId))
            ]
        )
        
        // Simulate new channel creation in DB
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: dummyChannel)
        }
        
        // Create controller for the existing new DM channel
        setupControllerForNewDirectMessageChannel(currentUserId: currentUserId, otherUserId: otherUserId)
        
        // Create and set delegate
        let delegate = ChannelController_Delegate(expectedQueueId: controllerCallbackQueueID)
        controller.delegate = delegate
        
        // Simulate synchronize
        controller.synchronize()
        
        // Simulate successful backend channel creation
        env.channelUpdater!.update_channelCreatedCallback?(dummyChannel.channel.cid)
        
        // Simulate successful network call.
        env.channelUpdater!.update_completion?(.success(dummyPayload(with: .unique)))
        
        // Since initially the controller doesn't know it's final `cid`, it can't report correct initial values.
        // That's why we simulate delegate callbacks for initial values.
        // Assert that delegate gets initial values as callback
        AssertAsync {
            Assert.willBeEqual(delegate.didUpdateChannel_channel?.item.cid, dummyChannel.channel.cid)
            Assert.willBeEqual(delegate.didUpdateMessages_messages?.count, dummyChannel.messages.count)
        }
    }
    
    // MARK: - New channel creation tests
    
    func test_controller_reportsInitialValues_forNewChannel_ifChannelDoesntExistLocally() throws {
        // Create controller for the non-existent new DM channel
        setupControllerForNewMessageChannel(cid: channelId)
        
        // Simulate synchronize
        controller.synchronize()
        
        // Create dummy channel with messages
        let dummyChannel = dummyPayload(
            with: channelId,
            numberOfMessages: 10,
            members: [.dummy()]
        )
        
        // Simulate successful backend channel creation
        env.channelUpdater!.update_channelCreatedCallback?(dummyChannel.channel.cid)
        
        // Simulate new channel creation in DB
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: dummyChannel)
        }
        
        // Simulate successful network call
        env.channelUpdater!.update_completion?(.success(dummyPayload(with: .unique)))
        
        // Assert that initial reported values are correct
        XCTAssertEqual(controller.channel?.cid, dummyChannel.channel.cid)
        XCTAssertEqual(controller.messages.count, dummyChannel.messages.count)
    }
    
    func test_controller_reportsInitialValues_forNewChannel_ifChannelExistsLocally() throws {
        // Create dummy channel with messages
        let dummyChannel = dummyPayload(
            with: channelId,
            numberOfMessages: 10,
            members: [.dummy()]
        )
        
        // Simulate new channel creation in DB
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: dummyChannel)
        }
        
        // Create controller for the existing new DM channel
        setupControllerForNewMessageChannel(cid: channelId)
        
        // Unlike new DM ChannelController, this ChannelController knows it's final `cid` so it should be able to fetch initial values
        // from DB, without the `synchronize` call
        // Assert that initial reported values are correct
        XCTAssertEqual(controller.channel?.cid, dummyChannel.channel.cid)
        XCTAssertEqual(controller.messages.count, dummyChannel.messages.count)
    }
    
    // MARK: - Updating channel
    
    func test_updateChannel_failsForNewChannels() throws {
        //  Create `ChannelController` for new channel
        let query = ChannelQuery(channelPayload: .unique)
        setupControllerForNewChannel(query: query)

        // Simulate `updateChannel` call and assert the error is returned
        var error: Error? = try waitFor { [callbackQueueID] completion in
            controller.updateChannel(name: .unique, imageURL: .unique(), team: nil, extraData: .init()) { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
        }
        XCTAssert(error is ClientError.ChannelNotCreatedYet)

        // Simulate succsesfull backend channel creation
        env.channelUpdater!.update_channelCreatedCallback?(query.cid!)

        // Simulate `updateChannel` call and assert no error is returned
        error = try waitFor { [callbackQueueID] completion in
            controller.updateChannel(name: .unique, imageURL: .unique(), team: nil, extraData: .init()) { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
            env.channelUpdater!.updateChannel_completion?(nil)
        }
        XCTAssertNil(error)
    }

    func test_updateChannel_callsChannelUpdater() {
        // Simulate `updateChannel` call and catch the completion
        var completionCalled = false
        controller.updateChannel(name: .unique, imageURL: .unique(), team: .unique, extraData: .init()) { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            completionCalled = true
        }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Assert payload is passed to `channelUpdater`, completion is not called yet
        XCTAssertNotNil(env.channelUpdater!.updateChannel_payload)
        
        // Simulate successful update
        env.channelUpdater!.updateChannel_completion?(nil)
        // Release reference of completion so we can deallocate stuff
        env.channelUpdater!.updateChannel_completion = nil
        
        // Assert completion is called
        AssertAsync.willBeTrue(completionCalled)
        // `weakController` should be deallocated too
        AssertAsync.canBeReleased(&weakController)
    }
    
    func test_updateChannel_propagesErrorFromUpdater() {
        // Simulate `updateChannel` call and catch the completion
        var completionCalledError: Error?
        controller.updateChannel(name: .unique, imageURL: .unique(), team: .unique, extraData: .init()) { [callbackQueueID] in
            AssertTestQueue(withId: callbackQueueID)
            completionCalledError = $0
        }
        
        // Simulate failed update
        let testError = TestError()
        env.channelUpdater!.updateChannel_completion?(testError)
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
    }

    // MARK: - Muting channel
    
    func test_muteChannel_failsForNewChannels() throws {
        //  Create `ChannelController` for new channel
        let query = ChannelQuery(channelPayload: .unique)
        setupControllerForNewChannel(query: query)

        // Simulate `muteChannel` call and assert error is returned
        var error: Error? = try waitFor { [callbackQueueID] completion in
            controller.muteChannel { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
        }
        XCTAssert(error is ClientError.ChannelNotCreatedYet)

        // Simulate successful backend channel creation
        env.channelUpdater!.update_channelCreatedCallback?(query.cid!)

        // Simulate `muteChannel` call and assert no error is returned
        error = try waitFor { [callbackQueueID] completion in
            controller.muteChannel { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
            env.channelUpdater!.muteChannel_completion?(nil)
        }

        XCTAssertNil(error)
    }

    func test_muteChannel_callsChannelUpdater() {
        // Simulate `muteChannel` call and catch the completion
        var completionCalled = false
        controller.muteChannel { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            completionCalled = true
        }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Assert cid and muted state are passed to `channelUpdater`, completion is not called yet
        XCTAssertEqual(env.channelUpdater!.muteChannel_cid, channelId)
        XCTAssertEqual(env.channelUpdater!.muteChannel_mute, true)
        XCTAssertFalse(completionCalled)
        
        // Simulate successful update
        env.channelUpdater!.muteChannel_completion?(nil)
        // Release reference of completion so we can deallocate stuff
        env.channelUpdater!.muteChannel_completion = nil
        
        // Assert completion is called
        AssertAsync.willBeTrue(completionCalled)
        // `weakController` should be deallocated too
        AssertAsync.canBeReleased(&weakController)
    }
    
    func test_muteChannel_propagatesErrorFromUpdater() {
        // Simulate `muteChannel` call and catch the completion
        var completionCalledError: Error?
        controller.muteChannel { [callbackQueueID] in
            AssertTestQueue(withId: callbackQueueID)
            completionCalledError = $0
        }
        
        // Simulate failed update
        let testError = TestError()
        env.channelUpdater!.muteChannel_completion?(testError)
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
    }

    // MARK: - Unmuting channel
    
    func test_unmuteChannel_failsForNewChannels() throws {
        //  Create `ChannelController` for new channel
        let query = ChannelQuery(channelPayload: .unique)
        setupControllerForNewChannel(query: query)

        // Simulate `unmuteChannel` call and assert error is returned
        var error: Error? = try waitFor { [callbackQueueID] completion in
            controller.muteChannel { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
        }
        XCTAssert(error is ClientError.ChannelNotCreatedYet)

        // Simulate successful backend channel creation
        env.channelUpdater!.update_channelCreatedCallback?(query.cid!)

        // Simulate `unmuteChannel` call and assert no error is returned
        error = try waitFor { [callbackQueueID] completion in
            controller.unmuteChannel { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
            env.channelUpdater!.muteChannel_completion?(nil)
        }

        XCTAssertNil(error)
    }

    func test_unmuteChannel_callsChannelUpdater() {
        // Simulate `unmuteChannel` call and catch the completion
        var completionCalled = false
        controller.unmuteChannel { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            completionCalled = true
        }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Assert cid and muted state are passed to `channelUpdater`, completion is not called yet
        XCTAssertEqual(env.channelUpdater!.muteChannel_cid, channelId)
        XCTAssertEqual(env.channelUpdater!.muteChannel_mute, false)
        XCTAssertFalse(completionCalled)
        
        // Simulate successful update
        env.channelUpdater!.muteChannel_completion?(nil)
        // Release reference of completion so we can deallocate stuff
        env.channelUpdater!.muteChannel_completion = nil
        
        // Assert completion is called
        AssertAsync.willBeTrue(completionCalled)
        // `weakController` should be deallocated too
        AssertAsync.canBeReleased(&weakController)
    }
    
    func test_unmuteChannel_propagatesErrorFromUpdater() {
        // Simulate `unmuteChannel` call and catch the completion
        var completionCalledError: Error?
        controller.unmuteChannel { [callbackQueueID] in
            AssertTestQueue(withId: callbackQueueID)
            completionCalledError = $0
        }
        
        // Simulate failed update
        let testError = TestError()
        env.channelUpdater!.muteChannel_completion?(testError)
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
    }

    // MARK: - Deleting channel
    
    func test_deleteChannel_failsForNewChannels() throws {
        //  Create `ChannelController` for new channel
        let query = ChannelQuery(channelPayload: .unique)
        setupControllerForNewChannel(query: query)

        // Simulate `deleteChannel` call and assert error is returned
        var error: Error? = try waitFor { [callbackQueueID] completion in
            controller.deleteChannel { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
        }
        XCTAssert(error is ClientError.ChannelNotCreatedYet)

        // Simulate successful backend channel creation
        env.channelUpdater!.update_channelCreatedCallback?(query.cid!)

        // Simulate `deleteChannel` call and assert no error is returned
        error = try waitFor { [callbackQueueID] completion in
            controller.deleteChannel { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
            env.channelUpdater!.deleteChannel_completion?(nil)
        }

        XCTAssertNil(error)
    }

    func test_deleteChannel_callsChannelUpdater() {
        // Simulate `deleteChannel` calls and catch the completion
        var completionCalled = false
        controller.deleteChannel { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            completionCalled = true
        }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Completion shouldn't be called yet
        XCTAssertFalse(completionCalled)
        XCTAssertEqual(env.channelUpdater?.deleteChannel_cid, channelId)
        
        // Simulate successful update
        env.channelUpdater?.deleteChannel_completion?(nil)
        // Release reference of completion so we can deallocate stuff
        env.channelUpdater!.deleteChannel_completion = nil
        
        // Completion should be called
        AssertAsync.willBeTrue(completionCalled)
        // `weakController` should be deallocated too
        AssertAsync.canBeReleased(&weakController)
    }
    
    func test_deleteChannel_callsChannelUpdaterWithError() {
        // Simulate `muteChannel` call and catch the completion
        var completionCalledError: Error?
        controller.deleteChannel { [callbackQueueID] in
            AssertTestQueue(withId: callbackQueueID)
            completionCalledError = $0
        }
        
        // Simulate failed update
        let testError = TestError()
        env.channelUpdater!.deleteChannel_completion?(testError)
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
    }
    
    // MARK: - Truncating channel

    func test_truncateChannel_failsForNewChannels() throws {
        //  Create `ChannelController` for new channel
        let query = ChannelQuery(channelPayload: .unique)
        setupControllerForNewChannel(query: query)

        // Simulate `truncateChannel` call and assert error is returned
        var error: Error? = try waitFor { [callbackQueueID] completion in
            controller.truncateChannel { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
        }
        XCTAssert(error is ClientError.ChannelNotCreatedYet)

        // Simulate successful backend channel creation
        env.channelUpdater!.update_channelCreatedCallback?(query.cid!)

        // Simulate `truncateChannel` call and assert no error is returned
        error = try waitFor { [callbackQueueID] completion in
            controller.truncateChannel { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
            env.channelUpdater!.truncateChannel_completion?(nil)
        }

        XCTAssertNil(error)
    }

    func test_truncateChannel_callsChannelUpdater() {
        // Simulate `truncateChannel` calls and catch the completion
        var completionCalled = false
        controller.truncateChannel { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            completionCalled = true
        }

        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller

        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil

        // Completion shouldn't be called yet
        XCTAssertFalse(completionCalled)
        XCTAssertEqual(env.channelUpdater?.truncateChannel_cid, channelId)

        // Simulate successful update
        env.channelUpdater?.truncateChannel_completion?(nil)
        // Release reference of completion so we can deallocate stuff
        env.channelUpdater!.truncateChannel_completion = nil

        // Completion should be called
        AssertAsync.willBeTrue(completionCalled)
        // `weakController` should be deallocated too
        AssertAsync.canBeReleased(&weakController)
    }

    func test_truncateChannel_callsChannelUpdaterWithError() {
        // Simulate `truncateChannel` call and catch the completion
        var completionCalledError: Error?
        controller.truncateChannel { [callbackQueueID] in
            AssertTestQueue(withId: callbackQueueID)
            completionCalledError = $0
        }

        // Simulate failed update
        let testError = TestError()
        env.channelUpdater!.truncateChannel_completion?(testError)

        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
    }

    // MARK: - Hiding channel

    func test_hideChannel_failsForNewChannels() throws {
        //  Create `ChannelController` for new channel
        let query = ChannelQuery(channelPayload: .unique)
        setupControllerForNewChannel(query: query)

        // Simulate `hideChannel` call and assert error is returned
        var error: Error? = try waitFor { [callbackQueueID] completion in
            controller.hideChannel { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
        }
        XCTAssert(error is ClientError.ChannelNotCreatedYet)

        // Simulate successful backend channel creation
        env.channelUpdater!.update_channelCreatedCallback?(query.cid!)

        // Simulate `hideChannel` call and assert no error is returned
        error = try waitFor { [callbackQueueID] completion in
            controller.hideChannel { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
            env.channelUpdater!.hideChannel_completion?(nil)
        }

        XCTAssertNil(error)
    }

    func test_hideChannel_callsChannelUpdater() {
        // Simulate `hideChannel` calls and catch the completion
        var completionCalled = false
        controller.hideChannel(clearHistory: false) { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            completionCalled = true
        }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Completion shouldn't be called yet
        XCTAssertFalse(completionCalled)
        XCTAssertEqual(env.channelUpdater?.hideChannel_cid, channelId)
        XCTAssertEqual(env.channelUpdater?.hideChannel_clearHistory, false)
        
        // Simulate successful update
        env.channelUpdater?.hideChannel_completion?(nil)
        // Release reference of completion so we can deallocate stuff
        env.channelUpdater!.hideChannel_completion = nil
        
        // Completion should be called
        AssertAsync.willBeTrue(completionCalled)
        // `weakController` should be deallocated too
        AssertAsync.canBeReleased(&weakController)
    }
    
    func test_hideChannel_callsChannelUpdaterWithError() {
        // Simulate `hideChannel` call and catch the completion
        var completionCalledError: Error?
        controller.hideChannel(clearHistory: false) { [callbackQueueID] in
            AssertTestQueue(withId: callbackQueueID)
            completionCalledError = $0
        }
        
        // Simulate failed update
        let testError = TestError()
        env.channelUpdater!.hideChannel_completion?(testError)
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
    }
    
    // MARK: - Showing channel

    func test_showChannel_failsForNewChannels() throws {
        //  Create `ChannelController` for new channel
        let query = ChannelQuery(channelPayload: .unique)
        setupControllerForNewChannel(query: query)

        // Simulate `showChannel` call and assert error is returned
        var error: Error? = try waitFor { [callbackQueueID] completion in
            controller.showChannel { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
        }
        XCTAssert(error is ClientError.ChannelNotCreatedYet)

        // Simulate successful backend channel creation
        env.channelUpdater!.update_channelCreatedCallback?(query.cid!)

        // Simulate `showChannel` call and assert no error is returned
        error = try waitFor { [callbackQueueID] completion in
            controller.showChannel { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
            env.channelUpdater!.showChannel_completion?(nil)
        }

        XCTAssertNil(error)
    }

    func test_showChannel_callsChannelUpdater() {
        // Simulate `showChannel` calls and catch the completion
        var completionCalled = false
        controller.showChannel { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            completionCalled = true
        }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Completion shouldn't be called yet
        XCTAssertFalse(completionCalled)
        XCTAssertEqual(env.channelUpdater?.showChannel_cid, channelId)

        // Simulate successful update
        env.channelUpdater?.showChannel_completion?(nil)
        // Release reference of completion so we can deallocate stuff
        env.channelUpdater!.showChannel_completion = nil
        
        // Completion should be called
        AssertAsync.willBeTrue(completionCalled)
        // `weakController` should be deallocated too
        AssertAsync.canBeReleased(&weakController)
    }
    
    func test_showChannel_callsChannelUpdaterWithError() {
        // Simulate `showChannel` call and catch the completion
        var completionCalledError: Error?
        controller.showChannel { [callbackQueueID] in
            AssertTestQueue(withId: callbackQueueID)
            completionCalledError = $0
        }
        
        // Simulate failed update
        let testError = TestError()
        env.channelUpdater!.showChannel_completion?(testError)
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
    }
    
    // MARK: - `loadPreviousMessages`
    
    func test_loadPreviousMessages_callsChannelUpdater() throws {
        var error: Error?
        var messageId: MessageId?
        
        // Create new channel with message in DB
        error = try waitFor {
            client.databaseContainer.write({ session in
                messageId = try self.setupChannelWithMessage(session)
            }, completion: $0)
        }
        
        XCTAssertNil(error)
        
        var completionCalled = false
        controller.loadPreviousMessages(before: messageId, limit: 25) { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            completionCalled = true
        }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Completion shouldn't be called yet
        XCTAssertFalse(completionCalled)
        // Assert correct `MessagesPagination` is created
        XCTAssertEqual(
            env!.channelUpdater?.update_channelQuery?.pagination,
            MessagesPagination(pageSize: 25, parameter: .lessThan(messageId!))
        )
        
        // Simulate successful update
        env.channelUpdater?
            .update_completion?(.success(dummyPayload(
                with: .unique,
                messages: [.dummy(messageId: .unique, authorUserId: .unique)]
            )))
        // Release reference of completion so we can deallocate stuff
        env.channelUpdater!.update_completion = nil
        
        // Completion should be called
        AssertAsync.willBeTrue(completionCalled)
        // `weakController` should be deallocated too
        AssertAsync.canBeReleased(&weakController)
    }

    func test_loadPreviousMessages_whenHasLoadedAllPreviousMessages_dontCallChannelUpdater() throws {
        var error: Error?
        var messageId: MessageId?

        // Create new channel with message in DB
        error = try waitFor {
            client.databaseContainer.write({ session in
                messageId = try self.setupChannelWithMessage(session)
            }, completion: $0)
        }

        XCTAssertNil(error)

        // By loading less messages than the limit, it means
        // we loaded all messages, and there's no more pages
        let pageSize = 25
        let numberOfMessagesFetched = 20

        // Load all the previous message
        var firstLoadCompletionCalled = false
        controller.loadPreviousMessages(before: messageId, limit: pageSize) { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            firstLoadCompletionCalled = true
        }

        // Completion shouldn't be called yet
        XCTAssertFalse(firstLoadCompletionCalled)

        // Assert correct `MessagesPagination` is created
        XCTAssertEqual(
            env!.channelUpdater?.update_channelQuery?.pagination,
            MessagesPagination(pageSize: pageSize, parameter: .lessThan(messageId!))
        )

        // Simulate channel update response with messages less than the limit
        // Which should switch the flag of all messages loaded to true
        env.channelUpdater?
            .update_completion?(.success(dummyPayload(
                with: .unique,
                numberOfMessages: numberOfMessagesFetched
            )))

        // Since the messages have been all loaded already, the second call
        // to load the previous message should not make any request
        var secondLoadCompletionCalled = false
        controller.loadPreviousMessages(before: messageId, limit: pageSize) { error in
            XCTAssertNil(error)
            secondLoadCompletionCalled = true
        }

        // Wait for the first load to be completed
        AssertAsync.willBeTrue(firstLoadCompletionCalled)
        // Wait for the second load to be completed
        AssertAsync.willBeTrue(secondLoadCompletionCalled)
        // Make sure the channel updater is only called the first time
        AssertAsync.willBeEqual(env.channelUpdater?.update_callCount, 1)
    }

    func test_loadPreviousMessages_whenLoadedMessagesLessThanLimit_dontFetchMoreMessages() throws {
        var error: Error?
        var messageId: MessageId?

        // Create new channel with message in DB
        error = try waitFor {
            client.databaseContainer.write({ session in
                messageId = try self.setupChannelWithMessage(session)
            }, completion: $0)
        }

        XCTAssertNil(error)

        // By loading less messages than the limit, it means
        // we loaded all messages, and there's no more pages
        let pageSize = 25
        let numberOfMessagesFetched = 20

        // Load all the previous message
        var loadCompletionCalled = false
        controller.loadPreviousMessages(before: messageId, limit: pageSize) { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            loadCompletionCalled = true
        }

        // Completion shouldn't be called yet
        XCTAssertFalse(loadCompletionCalled)

        // Simulate channel update response
        env.channelUpdater?
            .update_completion?(.success(dummyPayload(
                with: .unique,
                numberOfMessages: numberOfMessagesFetched
            )))

        // Wait for the load to be completed
        AssertAsync.willBeTrue(loadCompletionCalled)
        // Assert that no more messages will be loaded
        AssertAsync.willBeEqual(controller.hasLoadedAllPreviousMessages, true)
    }

    func test_loadPreviousMessages_whenLoadedMessagesEqualToLimit_fetchMoreMessages() throws {
        var error: Error?
        var messageId: MessageId?

        // Create new channel with message in DB
        error = try waitFor {
            client.databaseContainer.write({ session in
                messageId = try self.setupChannelWithMessage(session)
            }, completion: $0)
        }

        XCTAssertNil(error)

        // The number of messages loaded == pageSize,
        // then we should load more messages
        let pageSize = 25
        let numberOfMessagesFetched = 25

        // Load all the previous message
        var loadCompletionCalled = false
        controller.loadPreviousMessages(before: messageId, limit: pageSize) { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            loadCompletionCalled = true
        }

        // Completion shouldn't be called yet
        XCTAssertFalse(loadCompletionCalled)

        // Simulate channel update response
        env.channelUpdater?
            .update_completion?(.success(dummyPayload(
                with: .unique,
                numberOfMessages: numberOfMessagesFetched
            )))

        // Wait for the load to be completed
        AssertAsync.willBeTrue(loadCompletionCalled)
        // Assert that more messages will be loaded
        AssertAsync.willBeEqual(controller.hasLoadedAllPreviousMessages, false)
    }
    
    func test_loadPreviousMessages_throwsError_on_emptyMessages() throws {
        // Simulate `loadPreviousMessages` call and assert error is returned
        let error: Error? = try waitFor { [callbackQueueID] completion in
            controller.loadPreviousMessages { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
        }
        XCTAssert(error is ClientError.ChannelEmptyMessages)
    }
    
    func test_loadPreviousMessages_callsChannelUpdaterWithError() throws {
        var error: Error?
        var messageId: MessageId?
        
        // Create new channel with message in DB
        error = try waitFor {
            client.databaseContainer.write({ session in
                messageId = try self.setupChannelWithMessage(session)
            }, completion: $0)
        }
        
        XCTAssertNil(error)
        
        // Simulate `loadPreviousMessages` call and catch the completion
        var completionCalledError: Error?
        controller.loadPreviousMessages(before: messageId) { [callbackQueueID] in
            AssertTestQueue(withId: callbackQueueID)
            completionCalledError = $0
        }
        
        // Simulate failed update
        let testError = TestError()
        env.channelUpdater!.update_completion?(.failure(testError))
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
    }
    
    // MARK: - `loadNextMessages`
    
    func test_loadNextMessages_callsChannelUpdate() throws {
        var error: Error?
        var messageId: MessageId?
        
        // Create new channel with message in DB
        error = try waitFor {
            client.databaseContainer.write({ session in
                messageId = try self.setupChannelWithMessage(session)
            }, completion: $0)
        }
        
        XCTAssertNil(error)
        
        var completionCalled = false
        controller.loadNextMessages(after: messageId, limit: 25) { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            completionCalled = true
        }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Completion shouldn't be called yet
        XCTAssertFalse(completionCalled)
        // Assert correct `MessagesPagination` is created
        XCTAssertEqual(
            env!.channelUpdater?.update_channelQuery?.pagination,
            MessagesPagination(pageSize: 25, parameter: .greaterThan(messageId!))
        )
        
        // Simulate successful update
        env.channelUpdater?.update_completion?(.success(dummyPayload(with: .unique)))
        // Release reference of completion so we can deallocate stuff
        env.channelUpdater!.update_completion = nil
        
        // Completion should be called
        AssertAsync.willBeTrue(completionCalled)
        // `weakController` should be deallocated too
        AssertAsync.canBeReleased(&weakController)
    }
    
    func test_loadNextMessages_throwsError_on_emptyMessages() throws {
        // Simulate `loadNextMessages` call and assert error is returned
        let error: Error? = try waitFor { [callbackQueueID] completion in
            controller.loadNextMessages { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
        }
        XCTAssert(error is ClientError.ChannelEmptyMessages)
    }
    
    func test_loadNextMessages_callsChannelUpdaterWithError() throws {
        var error: Error?
        var messageId: MessageId?
        
        // Create new channel with message in DB
        error = try waitFor {
            client.databaseContainer.write({ session in
                messageId = try self.setupChannelWithMessage(session)
            }, completion: $0)
        }
        
        XCTAssertNil(error)
        
        // Simulate `loadPreviousMessages` call and catch the completion
        var completionCalledError: Error?
        controller.loadNextMessages(after: messageId) { [callbackQueueID] in
            AssertTestQueue(withId: callbackQueueID)
            completionCalledError = $0
        }
        
        // Simulate failed update
        let testError = TestError()
        env.channelUpdater!.update_completion?(.failure(testError))
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
    }
    
    // MARK: - Keystroke
    
    func test_keystroke() throws {
        let payload = dummyPayload(with: channelId, channelConfig: ChannelConfig(typingEventsEnabled: true))
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: payload)
        }

        controller.sendKeystrokeEvent {
            XCTAssertNil($0)
        }
        
        // Simulate `keystroke` call and catch the completion
        var completionCalledError: Error?
        controller.sendKeystrokeEvent { completionCalledError = $0 }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Check keystroke cid.
        XCTAssertEqual(env.eventSender!.keystroke_cid, channelId)
        
        // Simulate failed update
        let testError = TestError()
        env.eventSender!.keystroke_completion!(testError)
        // Release reference of completion so we can deallocate stuff
        env.eventSender!.keystroke_completion = nil
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
        // `weakController` should be deallocated too
        AssertAsync.canBeReleased(&weakController)
    }
    
    func test_keystroke_withParentMessageId() throws {
        let payload = dummyPayload(with: channelId, channelConfig: ChannelConfig(typingEventsEnabled: true))
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: payload)
        }
        
        let parentMessageId = MessageId.unique
        
        // Simulate `keystroke` call and catch the completion
        var completionCalledError: Error?
        controller.sendKeystrokeEvent(parentMessageId: parentMessageId) { completionCalledError = $0 }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Check keystroke cid and parentMessageId.
        XCTAssertEqual(env.eventSender!.keystroke_cid, channelId)
        XCTAssertEqual(env.eventSender!.keystroke_parentMessageId, parentMessageId)
        
        // Simulate failed update
        let testError = TestError()
        env.eventSender!.keystroke_completion!(testError)
        // Release reference of completion so we can deallocate stuff
        env.eventSender!.keystroke_completion = nil
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
        // `weakController` should be deallocated too
        AssertAsync.canBeReleased(&weakController)
    }
    
    func test_startTyping() throws {
        let payload = dummyPayload(with: channelId, channelConfig: ChannelConfig(typingEventsEnabled: true))
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: payload)
        }

        controller.sendStartTypingEvent {
            XCTAssertNil($0)
        }
        
        // Simulate `startTyping` call and catch the completion
        var completionCalledError: Error?
        controller.sendStartTypingEvent { completionCalledError = $0 }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Check `startTyping` cid.
        XCTAssertEqual(env.eventSender!.startTyping_cid, channelId)
        
        // Simulate failed update
        let testError = TestError()
        env.eventSender!.startTyping_completion!(testError)
        // Release reference of completion so we can deallocate stuff
        env.eventSender!.startTyping_completion = nil
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
        // `weakController` should be deallocated too
        AssertAsync.canBeReleased(&weakController)
    }
    
    func test_startTyping_withParentMessageId() throws {
        let payload = dummyPayload(with: channelId, channelConfig: ChannelConfig(typingEventsEnabled: true))
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: payload)
        }
        
        let parentMessageId = MessageId.unique
        
        // Simulate `startTyping` call and catch the completion
        var completionCalledError: Error?
        controller.sendStartTypingEvent(parentMessageId: parentMessageId) { completionCalledError = $0 }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Check `startTyping` cid and parentMessageId.
        XCTAssertEqual(env.eventSender!.startTyping_cid, channelId)
        XCTAssertEqual(env.eventSender!.startTyping_parentMessageId, parentMessageId)
        
        // Simulate failed update
        let testError = TestError()
        env.eventSender!.startTyping_completion!(testError)
        // Release reference of completion so we can deallocate stuff
        env.eventSender!.startTyping_completion = nil
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
        // `weakController` should be deallocated too
        AssertAsync.canBeReleased(&weakController)
    }
    
    func test_stopTyping() throws {
        let payload = dummyPayload(with: channelId, channelConfig: ChannelConfig(typingEventsEnabled: true))
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: payload)
        }

        controller.sendStopTypingEvent {
            XCTAssertNil($0)
        }
        
        // Simulate `stopTyping` call and catch the completion
        var completionCalledError: Error?
        controller.sendStopTypingEvent { completionCalledError = $0 }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Check `stopTyping` cid.
        XCTAssertEqual(env.eventSender!.stopTyping_cid, channelId)
        
        // Simulate failed update
        let testError = TestError()
        env.eventSender!.stopTyping_completion!(testError)
        // Release reference of completion so we can deallocate stuff
        env.eventSender!.stopTyping_completion = nil
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
        // `weakController` should be deallocated too
        AssertAsync.canBeReleased(&weakController)
    }
    
    func test_stopTyping_withParentMessageId() throws {
        let payload = dummyPayload(with: channelId, channelConfig: ChannelConfig(typingEventsEnabled: true))
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: payload)
        }
        
        let parentMessageId = MessageId.unique
        
        // Simulate `stopTyping` call and catch the completion
        var completionCalledError: Error?
        controller.sendStopTypingEvent(parentMessageId: parentMessageId) { completionCalledError = $0 }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Check `stopTyping` cid and parentMessageId.
        XCTAssertEqual(env.eventSender!.stopTyping_cid, channelId)
        XCTAssertEqual(env.eventSender!.stopTyping_parentMessageId, parentMessageId)
        
        // Simulate failed update
        let testError = TestError()
        env.eventSender!.stopTyping_completion!(testError)
        // Release reference of completion so we can deallocate stuff
        env.eventSender!.stopTyping_completion = nil
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
        // `weakController` should be deallocated too
        AssertAsync.canBeReleased(&weakController)
    }
    
    func test_sendKeystrokeEvent_whenTypingEventsAreDisabled_doesNothing() throws {
        let payload = dummyPayload(with: channelId, channelConfig: ChannelConfig(typingEventsEnabled: false))
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: payload)
        }

        var completionCalled = false

        let error: Error? = try waitFor { completion in
            controller.sendKeystrokeEvent {
                completionCalled = true
                completion($0)
            }
        }
        
        XCTAssertTrue(completionCalled)
        XCTAssertNil(error)
    }
    
    func test_sendStartTypingEvent_whenTypingEventsAreDisabled_errors() throws {
        let payload = dummyPayload(with: channelId, channelConfig: ChannelConfig(typingEventsEnabled: false))
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: payload)
        }

        var completionCalled = false

        let error: Error? = try waitFor { completion in
            controller.sendStartTypingEvent {
                completionCalled = true
                completion($0)
            }
        }
        
        XCTAssertTrue(completionCalled)
        XCTAssertNotNil(error)
        
        guard let channelFeatureError = error as? ClientError.ChannelFeatureDisabled else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(channelFeatureError.localizedDescription, "Channel feature: typing events is disabled for this channel.")
    }
    
    func test_sendStopTypingEvent_whenTypingEventsAreDisabled_errors() throws {
        let payload = dummyPayload(with: channelId, channelConfig: ChannelConfig(typingEventsEnabled: false))
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: payload)
        }

        var completionCalled = false

        let error: Error? = try waitFor { completion in
            controller.sendStopTypingEvent {
                completionCalled = true
                completion($0)
            }
        }
        
        XCTAssertTrue(completionCalled)
        XCTAssertNotNil(error)
        
        guard let channelFeatureError = error as? ClientError.ChannelFeatureDisabled else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(channelFeatureError.localizedDescription, "Channel feature: typing events is disabled for this channel.")
    }
    
    func test_keystroke_keepsControllerAlive() throws {
        // Save channel with typing events enabled to database
        try client.mockDatabaseContainer.writeSynchronously {
            try $0.saveChannel(
                payload: self.dummyPayload(
                    with: self.channelId,
                    channelConfig: .init(typingEventsEnabled: true)
                )
            )
        }
        
        // Simulate `sendKeystrokeEvent` call.
        controller.sendKeystrokeEvent()
        
        // Create a weak ref and release a controller.
        weak var weakController = controller
        controller = nil
        
        // Assert controller is kept alive
        AssertAsync.staysTrue(weakController != nil)
    }
    
    func test_startTyping_keepsControllerAlive() throws {
        // Save channel with typing events enabled to database
        try client.mockDatabaseContainer.writeSynchronously {
            try $0.saveChannel(
                payload: self.dummyPayload(
                    with: self.channelId,
                    channelConfig: .init(typingEventsEnabled: true)
                )
            )
        }
        
        // Simulate `sendStartTypingEvent` call.
        controller.sendStartTypingEvent()
        
        // Create a weak ref and release a controller.
        weak var weakController = controller
        controller = nil
        
        // Assert controller is kept alive
        AssertAsync.staysTrue(weakController != nil)
    }
    
    func test_stopTyping_keepsControllerAlive() throws {
        // Save channel with typing events enabled to database
        try client.mockDatabaseContainer.writeSynchronously {
            try $0.saveChannel(
                payload: self.dummyPayload(
                    with: self.channelId,
                    channelConfig: .init(typingEventsEnabled: true)
                )
            )
        }
        
        // Simulate `sendStopTypingEvent` call.
        controller.sendStopTypingEvent()
        
        // Create a weak ref and release a controller.
        weak var weakController = controller
        controller = nil
        
        // Assert controller is kept alive
        AssertAsync.staysTrue(weakController != nil)
    }
    
    // MARK: - Message sending
    
    func test_createNewMessage_callsChannelUpdater() {
        let newMessageId: MessageId = .unique
        
        // New message values
        let text: String = .unique
        let extraData: [String: RawJSON] = [:]
        let attachments: [AnyAttachmentPayload] = [
            .init(payload: TestAttachmentPayload.unique),
            .mockImage,
            .mockFile
        ]
        let quotedMessageId: MessageId = .unique
        let pin = MessagePinning(expirationDate: .unique)
        
        // Simulate `createNewMessage` calls and catch the completion
        var completionCalled = false
        controller.createNewMessage(
            text: text,
            pinning: pin,
            attachments: attachments,
            quotedMessageId: quotedMessageId,
            extraData: extraData
        ) { [callbackQueueID] result in
            AssertTestQueue(withId: callbackQueueID)
            AssertResultSuccess(result, newMessageId)
            completionCalled = true
        }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Completion shouldn't be called yet
        XCTAssertFalse(completionCalled)
        XCTAssertEqual(env.channelUpdater?.createNewMessage_cid, channelId)
        XCTAssertEqual(env.channelUpdater?.createNewMessage_text, text)
        //        XCTAssertEqual(env.channelUpdater?.createNewMessage_command, command)
        //        XCTAssertEqual(env.channelUpdater?.createNewMessage_arguments, arguments)
        XCTAssertEqual(env.channelUpdater?.createNewMessage_extraData, extraData)
        XCTAssertEqual(env.channelUpdater?.createNewMessage_attachments, attachments)
        XCTAssertEqual(env.channelUpdater?.createNewMessage_quotedMessageId, quotedMessageId)
        XCTAssertEqual(env.channelUpdater?.createNewMessage_pinning?.expirationDate, pin.expirationDate!)
        
        // Simulate successful update
        env.channelUpdater?.createNewMessage_completion?(.success(newMessageId))
        // Release reference of completion so we can deallocate stuff
        env.channelUpdater!.createNewMessage_completion = nil
        
        // Completion should be called
        AssertAsync.willBeTrue(completionCalled)
        // `weakController` should be deallocated too
        AssertAsync.canBeReleased(&weakController)
    }
    
    func test_createNewMessage_failsForNewChannels() throws {
        //  Create `ChannelController` for new channel
        let query = ChannelQuery(channelPayload: .unique)
        setupControllerForNewChannel(query: query)
        
        // Simulate `createNewMessage` call and assert error is returned
        let result: Result<MessageId, Error> = try waitFor { [callbackQueueID] completion in
            controller.createNewMessage(
                text: .unique,
//                command: .unique,
//                arguments: .unique,
                extraData: [:]
            ) { result in
                AssertTestQueue(withId: callbackQueueID)
                completion(result)
            }
        }
        
        if case let .failure(error) = result {
            XCTAssert(error is ClientError.ChannelNotCreatedYet)
        } else {
            XCTFail("Expected .failure but received \(result)")
        }
    }

    // MARK: - Adding members
    
    func test_addMembers_failsForNewChannels() throws {
        //  Create `ChannelController` for new channel
        let query = ChannelQuery(channelPayload: .unique)
        setupControllerForNewChannel(query: query)
        let members: Set<UserId> = [.unique]

        // Simulate `addMembers` call and assert error is returned
        var error: Error? = try waitFor { [callbackQueueID] completion in
            controller.addMembers(userIds: members) { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
        }
        XCTAssert(error is ClientError.ChannelNotCreatedYet)

        // Simulate successful backend channel creation
        env.channelUpdater!.update_channelCreatedCallback?(query.cid!)

        // Simulate `addMembers` call and assert no error is returned
        error = try waitFor { [callbackQueueID] completion in
            controller.addMembers(userIds: members) { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
            env.channelUpdater!.addMembers_completion?(nil)
        }

        XCTAssertNil(error)
    }

    func test_addMembers_callsChannelUpdater() {
        let members: Set<UserId> = [.unique]
        
        // Simulate `addMembers` call and catch the completion
        var completionCalled = false
        controller.addMembers(userIds: members) { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            completionCalled = true
        }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Assert cid and members state are passed to `channelUpdater`, completion is not called yet
        XCTAssertEqual(env.channelUpdater!.addMembers_cid, channelId)
        XCTAssertEqual(env.channelUpdater!.addMembers_userIds, members)
        XCTAssertFalse(completionCalled)
        
        // Simulate successful update
        env.channelUpdater!.addMembers_completion?(nil)
        // Release reference of completion so we can deallocate stuff
        env.channelUpdater!.addMembers_completion = nil
        
        // Assert completion is called
        AssertAsync.willBeTrue(completionCalled)
        // `weakController` should be deallocated too
        AssertAsync.canBeReleased(&weakController)
    }
    
    func test_addMembers_propagatesErrorFromUpdater() {
        let members: Set<UserId> = [.unique]
        
        // Simulate `addMembers` call and catch the completion
        var completionCalledError: Error?
        controller.addMembers(userIds: members) { [callbackQueueID] in
            AssertTestQueue(withId: callbackQueueID)
            completionCalledError = $0
        }
        
        // Simulate failed update
        let testError = TestError()
        env.channelUpdater!.addMembers_completion?(testError)
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
    }
    
    // MARK: - Inviting members
    
    func test_inviteMembers_callsChannelUpdater() {
        let members: Set<UserId> = [.unique, .unique]
        
        // Simulate `inviteMembers` call and catch the completion
        var completionCalled = false
        controller.inviteMembers(userIds: members) { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            completionCalled = true
        }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Assert cid and members state are passed to `channelUpdater`, completion is not called yet
        XCTAssertEqual(env.channelUpdater!.inviteMembers_cid, channelId)
        XCTAssertEqual(env.channelUpdater!.inviteMembers_userIds, members)
        XCTAssertFalse(completionCalled)
        
        // Simulate successful update
        env.channelUpdater!.inviteMembers_completion?(nil)
        // Release reference of completion so we can deallocate stuff
        env.channelUpdater!.inviteMembers_completion = nil
        
        // Assert completion is called
        AssertAsync.willBeTrue(completionCalled)
        // `weakController` should be deallocated too
        AssertAsync.canBeReleased(&weakController)
    }
    
    func test_inviteMembers_propagatesErrorFromUpdater() {
        let members: Set<UserId> = [.unique, .unique]
        
        // Simulate `inviteMembers` call and catch the completion
        var completionCalledError: Error?
        controller.inviteMembers(userIds: members) { [callbackQueueID] in
            AssertTestQueue(withId: callbackQueueID)
            completionCalledError = $0
        }
        
        // Simulate failed update
        let testError = TestError()
        env.channelUpdater!.inviteMembers_completion?(testError)
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
        controller = nil
    }
    
    // MARK: - Accepting invites
    
    func test_acceptInvite_callsChannelUpdater() {
        // Simulate `acceptInvite` call and catch the completion
        var completionCalled = false
        let message = "Hooray"
        controller.acceptInvite(message: message) { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            completionCalled = true
        }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Assert cid and members state are passed to `channelUpdater`, completion is not called yet
        XCTAssertEqual(env.channelUpdater!.acceptInvite_cid, channelId)
        XCTAssertEqual(env.channelUpdater!.acceptInvite_message, message)
        XCTAssertFalse(completionCalled)
        
        // Simulate successful update
        env.channelUpdater!.acceptInvite_completion?(nil)
        // Release reference of completion so we can deallocate stuff
        env.channelUpdater!.acceptInvite_completion = nil
        
        // Assert completion is called
        AssertAsync.willBeTrue(completionCalled)
        // `weakController` should be deallocated too
        AssertAsync.canBeReleased(&weakController)
    }
    
    func test_acceptInvite_propagatesErrorFromUpdater() {
        // Simulate `inviteMembers` call and catch the completion
        var completionCalledError: Error?
        controller.acceptInvite(message: "Hooray") { [callbackQueueID] in
            AssertTestQueue(withId: callbackQueueID)
            completionCalledError = $0
        }
        
        // Simulate failed update
        let testError = TestError()
        env.channelUpdater!.acceptInvite_completion?(testError)
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
        controller = nil
    }
    
    // MARK: - Accepting invites
    
    func test_rejectInvite_callsChannelUpdater() {
        // Simulate `acceptInvite` call and catch the completion
        var completionCalled = false
        controller.rejectInvite { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            completionCalled = true
        }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Assert cid and members state are passed to `channelUpdater`, completion is not called yet
        XCTAssertEqual(env.channelUpdater!.rejectInvite_cid, channelId)
        XCTAssertFalse(completionCalled)
        
        // Simulate successful update
        env.channelUpdater!.rejectInvite_completion?(nil)
        // Release reference of completion so we can deallocate stuff
        env.channelUpdater!.rejectInvite_completion = nil
        
        // Assert completion is called
        AssertAsync.willBeTrue(completionCalled)
        // `weakController` should be deallocated too
        AssertAsync.canBeReleased(&weakController)
    }
    
    func test_rejectInvite_propagatesErrorFromUpdater() {
        // Simulate `inviteMembers` call and catch the completion
        var completionCalledError: Error?
        controller.rejectInvite { [callbackQueueID] in
            AssertTestQueue(withId: callbackQueueID)
            completionCalledError = $0
        }
        
        // Simulate failed update
        let testError = TestError()
        env.channelUpdater!.rejectInvite_completion?(testError)
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
        controller = nil
    }
    
    // MARK: - Removing members
    
    func test_removeMembers_failsForNewChannels() throws {
        //  Create `ChannelController` for new channel
        let query = ChannelQuery(channelPayload: .unique)
        setupControllerForNewChannel(query: query)
        let members: Set<UserId> = [.unique]

        // Simulate `removeMembers` call and assert error is returned
        var error: Error? = try waitFor { [callbackQueueID] completion in
            controller.removeMembers(userIds: members) { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
        }
        XCTAssert(error is ClientError.ChannelNotCreatedYet)

        // Simulate successful backend channel creation
        env.channelUpdater!.update_channelCreatedCallback?(query.cid!)

        // Simulate `removeMembers` call and assert no error is returned
        error = try waitFor { [callbackQueueID] completion in
            controller.removeMembers(userIds: members) { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
            env.channelUpdater!.removeMembers_completion?(nil)
        }

        XCTAssertNil(error)
    }

    func test_removeMembers_callsChannelUpdater() {
        let members: Set<UserId> = [.unique]
        
        // Simulate `removeMembers` call and catch the completion
        var completionCalled = false
        controller.removeMembers(userIds: members) { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            completionCalled = true
        }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Assert cid and members state are passed to `channelUpdater`, completion is not called yet
        XCTAssertEqual(env.channelUpdater!.removeMembers_cid, channelId)
        XCTAssertEqual(env.channelUpdater!.removeMembers_userIds, members)
        XCTAssertFalse(completionCalled)
        
        // Simulate successful update
        env.channelUpdater!.removeMembers_completion?(nil)
        // Release reference of completion so we can deallocate stuff
        env.channelUpdater!.removeMembers_completion = nil
        
        // Assert completion is called
        AssertAsync.willBeTrue(completionCalled)
        // `weakController` should be deallocated too
        AssertAsync.canBeReleased(&weakController)
    }
    
    func test_removeMembers_propagatesErrorFromUpdater() {
        let members: Set<UserId> = [.unique]
        
        // Simulate `removeMembers` call and catch the completion
        var completionCalledError: Error?
        controller.removeMembers(userIds: members) { [callbackQueueID] in
            AssertTestQueue(withId: callbackQueueID)
            completionCalledError = $0
        }
        
        // Simulate failed update
        let testError = TestError()
        env.channelUpdater!.removeMembers_completion?(testError)
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
    }
    
    // MARK: - Mark read

    func test_markRead_whenReadEventsAreDisabled_errors() throws {
        let payload = dummyPayload(with: channelId, channelConfig: ChannelConfig(readEventsEnabled: false))
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: payload)
        }

        let error: Error? = try waitFor { completion in
            controller.markRead { error in
                completion(error)
            }
        }
        
        guard let channelFeatureError = error as? ClientError.ChannelFeatureDisabled else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(channelFeatureError.localizedDescription, "Channel feature: read events is disabled for this channel.")
    }

    func test_markRead_whenChannelIsMissing_throws() throws {
        //  Create `ChannelController` for new channel
        let query = ChannelQuery(channelPayload: .unique)
        setupControllerForNewChannel(query: query)
        
        // Simulate `markRead` call and assert error is returned
        var error: Error? = try waitFor { [callbackQueueID] completion in
            controller.markRead { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
        }
        XCTAssert(error is ClientError.ChannelNotCreatedYet)

        // Simulate successful backend channel creation
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: self.dummyPayload(with: query.cid!))
        }
        env.channelUpdater!.update_channelCreatedCallback?(query.cid!)
        
        // Simulate `markRead` call and assert no error is returned
        error = try waitFor { [callbackQueueID] completion in
            controller.markRead { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
            env.channelUpdater!.markRead_completion?(nil)
        }
        
        XCTAssertNil(error)
    }
    
    func test_markRead_whenChannelIsEmpty_doesNothing() throws {
        // GIVEN
        let currentUser: CurrentUserPayload = .dummy(userId: .unique, role: .user)

        let emptyChannel: ChannelPayload = .dummy(
            channel: .dummy(
                cid: channelId,
                lastMessageAt: nil,
                config: .mock(readEventsEnabled: true)
            ),
            messages: [],
            channelReads: []
        )
                
        try client.databaseContainer.writeSynchronously { session in
            try session.saveCurrentUser(payload: currentUser)
            
            try session.saveChannel(payload: emptyChannel)
        }
        
        client.currentUserId = currentUser.id
        
        // WHEN
        var completionCalled = false
        controller.markRead { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            completionCalled = true
        }
        
        // THEN
        AssertAsync {
            Assert.willBeTrue(completionCalled)
            Assert.staysTrue(self.env.channelUpdater?.markRead_cid == nil)
        }
    }
    
    func test_markRead_whenCurrentUserIsMissing_doesNothing() throws {
        // GIVEN
        let lastMessage: MessagePayload = .dummy(
            messageId: .unique,
            authorUserId: .unique,
            cid: channelId
        )
        
        let channel: ChannelPayload = .dummy(
            channel: .dummy(
                cid: channelId,
                lastMessageAt: lastMessage.createdAt,
                config: .mock(readEventsEnabled: true)
            ),
            messages: [lastMessage]
        )
        
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: channel)
        }
        
        // WHEN
        var completionCalled = false
        controller.markRead { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            completionCalled = true
        }
        
        // THEN
        AssertAsync {
            Assert.willBeTrue(completionCalled)
            Assert.staysTrue(self.env.channelUpdater?.markRead_cid == nil)
        }
    }
    
    func test_markRead_whenCurrentUserReadIsMissing_doesNothing() throws {
        // GIVEN
        let lastMessage: MessagePayload = .dummy(
            messageId: .unique,
            authorUserId: .unique,
            cid: channelId
        )
        
        let currentUser: CurrentUserPayload = .dummy(userId: .unique, role: .user)

        let channel: ChannelPayload = .dummy(
            channel: .dummy(
                cid: channelId,
                lastMessageAt: lastMessage.createdAt,
                config: .mock(readEventsEnabled: true)
            ),
            messages: [lastMessage],
            channelReads: []
        )
                
        try client.databaseContainer.writeSynchronously { session in
            try session.saveCurrentUser(payload: currentUser)
            
            try session.saveChannel(payload: channel)
        }
        
        client.currentUserId = currentUser.id
        
        // WHEN
        var completionCalled = false
        controller.markRead { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            completionCalled = true
        }
        
        // THEN
        AssertAsync {
            Assert.willBeTrue(completionCalled)
            Assert.staysTrue(self.env.channelUpdater?.markRead_cid == nil)
        }
    }
    
    func test_markRead_whenChannelIsRead_doesNothing() throws {
        // GIVEN
        let lastMessage: MessagePayload = .dummy(
            messageId: .unique,
            authorUserId: .unique,
            cid: channelId
        )
        
        let currentUser: CurrentUserPayload = .dummy(userId: .unique, role: .user)

        let channel: ChannelPayload = .dummy(
            channel: .dummy(cid: channelId, lastMessageAt: lastMessage.createdAt),
            messages: [lastMessage],
            channelReads: [
                .init(
                    user: currentUser,
                    lastReadAt: lastMessage.createdAt,
                    unreadMessagesCount: 0
                )
            ]
        )
                
        try client.databaseContainer.writeSynchronously { session in
            try session.saveCurrentUser(payload: currentUser)
            
            try session.saveChannel(payload: channel)
        }
        
        client.currentUserId = currentUser.id
        
        // WHEN
        var completionCalled = false
        controller.markRead { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            completionCalled = true
        }
        
        // THEN
        AssertAsync {
            Assert.willBeTrue(completionCalled)
            Assert.staysTrue(self.env.channelUpdater?.markRead_cid == nil)
        }
    }
    
    func test_markRead_whenLastMessageInUnread_callsChannelUpdater() throws {
        // GIVEN
        let lastMessage: MessagePayload = .dummy(
            messageId: .unique,
            authorUserId: .unique,
            cid: channelId
        )
        
        let currentUser: CurrentUserPayload = .dummy(userId: .unique, role: .user)

        let channel: ChannelPayload = .dummy(
            channel: .dummy(cid: channelId, lastMessageAt: lastMessage.createdAt),
            messages: [lastMessage],
            channelReads: [
                .init(
                    user: currentUser,
                    lastReadAt: lastMessage.createdAt.addingTimeInterval(-1),
                    unreadMessagesCount: 0
                )
            ]
        )
                
        try client.databaseContainer.writeSynchronously { session in
            try session.saveCurrentUser(payload: currentUser)
            try session.saveChannel(payload: channel)
        }
        
        client.currentUserId = currentUser.id
        
        // WHEN
        var completionCalled = false
        controller.markRead { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            completionCalled = true
        }
        
        // THEN
        XCTAssertEqual(env.channelUpdater!.markRead_cid, channelId)
        XCTAssertEqual(env.channelUpdater!.markRead_userId, currentUser.id)
        env.channelUpdater!.markRead_completion?(nil)
        
        AssertAsync.willBeTrue(completionCalled)
    }
    
    func test_markRead_propagatesErrorFromUpdater() throws {
        let payload = dummyPayload(with: channelId, numberOfMessages: 3)
        let dummyUserPayload: CurrentUserPayload = .dummy(userId: payload.channelReads.first!.user.id, role: .user)
        
        try client.databaseContainer.writeSynchronously { session in
            try session.saveCurrentUser(payload: dummyUserPayload)
            try session.saveChannel(payload: payload)
        }

        // This is needed to determine if the channel needs to be marked as read
        client.currentUserId = dummyUserPayload.id

        // Simulate `markRead` call and catch the completion
        var completionCalledError: Error?
        controller.markRead { [callbackQueueID] in
            AssertTestQueue(withId: callbackQueueID)
            completionCalledError = $0
        }
        
        // Simulate failed update
        let testError = TestError()
        env.channelUpdater!.markRead_completion?(testError)
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
    }
    
    func test_markRead_keepsControllerAlive() throws {
        // GIVEN
        let channel = dummyPayload(with: channelId, numberOfMessages: 3)
        let currentUser: CurrentUserPayload = .dummy(userId: channel.channelReads.first!.user.id, role: .user)
        client.currentUserId = currentUser.id

        try client.databaseContainer.writeSynchronously { session in
            try session.saveCurrentUser(payload: currentUser)
            try session.saveChannel(payload: channel)
        }
        
        controller.markRead { _ in }
        
        // WHEN
        weak var weakController = controller
        controller = nil
        
        // Assert controller is kept alive
        AssertAsync.staysTrue(weakController != nil)
    }
    
    // MARK: - Enable slow mode (cooldown)
    
    func test_enableSlowMode_failsForNewChannels() throws {
        //  Create `ChannelController` for new channel
        let query = ChannelQuery(channelPayload: .unique)
        setupControllerForNewChannel(query: query)
        
        // Simulate `enableSlowMode` call and assert error is returned
        var error: Error? = try waitFor { [callbackQueueID] completion in
            controller.enableSlowMode(cooldownDuration: .random(in: 1...120)) { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
        }
        XCTAssert(error is ClientError.ChannelNotCreatedYet)
        
        // Simulate successful backend channel creation
        env.channelUpdater!.update_channelCreatedCallback?(query.cid!)
        
        // Simulate `enableSlowMode` call and assert no error is returned
        error = try waitFor { [callbackQueueID] completion in
            controller.enableSlowMode(cooldownDuration: .random(in: 1...120)) { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
            env.channelUpdater!.enableSlowMode_completion?(nil)
        }
        
        XCTAssertNil(error)
    }
    
    func test_enableSlowMode_failsForInvalidCooldown() throws {
        //  Create `ChannelController` for new channel
        let query = ChannelQuery(channelPayload: .unique)
        setupControllerForNewChannel(query: query)
        
        // Simulate successful backend channel creation
        env.channelUpdater!.update_channelCreatedCallback?(query.cid!)
        
        // Simulate `enableSlowMode` call with invalid cooldown and assert error is returned
        var error: Error? = try waitFor { [callbackQueueID] completion in
            controller.enableSlowMode(cooldownDuration: .random(in: 130...250)) { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
        }
        XCTAssert(error is ClientError.InvalidCooldownDuration)
        
        // Simulate `enableSlowMode` call with another invalid cooldown and assert error is returned
        error = try waitFor { [callbackQueueID] completion in
            controller.enableSlowMode(cooldownDuration: .random(in: -100...0)) { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
        }
        XCTAssert(error is ClientError.InvalidCooldownDuration)
    }
    
    func test_enableSlowMode_callsChannelUpdater() {
        // Simulate `enableSlowMode` call and catch the completion
        var completionCalled = false
        controller.enableSlowMode(cooldownDuration: .random(in: 1...120)) { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            completionCalled = true
        }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Assert cid is passed to `channelUpdater`, completion is not called yet
        XCTAssertEqual(env.channelUpdater!.enableSlowMode_cid, channelId)
        XCTAssertFalse(completionCalled)
        
        // Simulate successful update
        env.channelUpdater!.enableSlowMode_completion?(nil)
        // Release reference of completion so we can deallocate stuff
        env.channelUpdater!.enableSlowMode_completion = nil
        
        // Assert completion is called
        AssertAsync.willBeTrue(completionCalled)
        // `weakController` should be deallocated too
        AssertAsync.canBeReleased(&weakController)
    }
    
    func test_enableSlowMode_propagatesErrorFromUpdater() {
        // Simulate `enableSlowMode` call and catch the completion
        var completionCalledError: Error?
        controller.enableSlowMode(cooldownDuration: .random(in: 1...120)) { [callbackQueueID] in
            AssertTestQueue(withId: callbackQueueID)
            completionCalledError = $0
        }
        
        // Simulate failed update
        let testError = TestError()
        env.channelUpdater!.enableSlowMode_completion?(testError)
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
    }
    
    // MARK: - Disable slow mode (cooldown)
    
    func test_disableSlowMode_failsForNewChannels() throws {
        //  Create `ChannelController` for new channel
        let query = ChannelQuery(channelPayload: .unique)
        setupControllerForNewChannel(query: query)
        
        // Simulate `disableSlowMode` call and assert error is returned
        var error: Error? = try waitFor { [callbackQueueID] completion in
            controller.disableSlowMode { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
        }
        XCTAssert(error is ClientError.ChannelNotCreatedYet)
        
        // Simulate successful backend channel creation
        env.channelUpdater!.update_channelCreatedCallback?(query.cid!)
        
        // Simulate `disableSlowMode` call and assert no error is returned
        error = try waitFor { [callbackQueueID] completion in
            controller.disableSlowMode { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
            env.channelUpdater!.enableSlowMode_completion?(nil)
        }
        
        XCTAssertNil(error)
    }
    
    func test_disableSlowMode_callsChannelUpdater() {
        // Simulate `disableSlowMode` call and catch the completion
        var completionCalled = false
        controller.disableSlowMode { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            completionCalled = true
        }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Assert cid is passed to `channelUpdater`, completion is not called yet
        XCTAssertEqual(env.channelUpdater!.enableSlowMode_cid, channelId)
        // Assert that passed cooldown duration is 0
        XCTAssertEqual(env.channelUpdater!.enableSlowMode_cooldownDuration, 0)
        XCTAssertFalse(completionCalled)
        
        // Simulate successful update
        env.channelUpdater!.enableSlowMode_completion?(nil)
        // Release reference of completion so we can deallocate stuff
        env.channelUpdater!.enableSlowMode_completion = nil
        
        // Assert completion is called
        AssertAsync.willBeTrue(completionCalled)
        // `weakController` should be deallocated too
        AssertAsync.canBeReleased(&weakController)
    }
    
    func test_disableSlowMode_propagatesErrorFromUpdater() {
        // Simulate `disableSlowMode` call and catch the completion
        var completionCalledError: Error?
        controller.disableSlowMode { [callbackQueueID] in
            AssertTestQueue(withId: callbackQueueID)
            completionCalledError = $0
        }
        
        // Simulate failed update
        let testError = TestError()
        env.channelUpdater!.enableSlowMode_completion?(testError)
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
    }
    
    func test_currentCooldownTime_whenSlowModeIsActive_andLastMessageFromCurrentUserExists_thenCooldownTimeIsGreaterThanZero(
    ) throws {
        // GIVEN
        let user: UserPayload = dummyCurrentUser
        let message: MessagePayload = .dummy(messageId: .unique, authorUserId: user.id, createdAt: Date())
        let channelPayload = dummyPayload(with: channelId, messages: [message], cooldownDuration: 5)
        
        try client.databaseContainer.createCurrentUser(id: user.id)
        
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: channelPayload)
        }
        
        // WHEN
        let currentCooldownTime = controller.currentCooldownTime()
        
        // THEN
        XCTAssertGreaterThan(currentCooldownTime, 0)
    }
    
    func test_currentCooldownTime_whenSlowModeIsNotActive_thenCooldownTimeIsZero() throws {
        // GIVEN
        let user: UserPayload = dummyCurrentUser
        let channelPayload = dummyPayload(with: channelId, cooldownDuration: 0)
        
        try client.databaseContainer.createCurrentUser(id: user.id)
        
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: channelPayload)
        }
        
        // WHEN
        let currentCooldownTime = controller.currentCooldownTime()
        
        // THEN
        XCTAssertEqual(currentCooldownTime, 0)
    }
    
    func test_currentCooldownTime_doesNotReturnNegativeValues() throws {
        // GIVEN
        let user: UserPayload = dummyCurrentUser
        
        let message: MessagePayload = .dummy(
            messageId: .unique,
            authorUserId: user.id,
            createdAt: Date().addingTimeInterval(-20)
        )
        
        let channelPayload = dummyPayload(
            with: channelId,
            messages: [message],
            cooldownDuration: 5
        )
        
        try client.databaseContainer.createCurrentUser(id: user.id)
        
        try client.databaseContainer.writeSynchronously { session in
            try session.saveChannel(payload: channelPayload)
        }
        
        // WHEN
        let currentCooldownTime = controller.currentCooldownTime()
        
        // THEN
        XCTAssertEqual(currentCooldownTime, 0)
    }
    
    // MARK: - Start watching
    
    func test_startWatching_failsForNewChannels() throws {
        //  Create `ChannelController` for new channel
        let query = ChannelQuery(channelPayload: .unique)
        setupControllerForNewChannel(query: query)
        
        // Simulate `startWatching` call and assert error is returned
        var error: Error? = try waitFor { [callbackQueueID] completion in
            controller.startWatching(isInRecoveryMode: false) { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
        }
        XCTAssert(error is ClientError.ChannelNotCreatedYet)
        
        // Simulate successful backend channel creation
        env.channelUpdater!.update_channelCreatedCallback?(query.cid!)
        
        // Simulate `startWatching` call and assert no error is returned
        error = try waitFor { [callbackQueueID] completion in
            controller.startWatching(isInRecoveryMode: false) { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
            env.channelUpdater!.startWatching_completion?(nil)
        }
        
        XCTAssertNil(error)
    }
    
    func test_startWatching_callsChannelUpdater() {
        // Simulate `startWatching` call and catch the completion
        var completionCalled = false
        controller.startWatching(isInRecoveryMode: false) { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            completionCalled = true
        }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Assert cid is passed to `channelUpdater`, completion is not called yet
        XCTAssertEqual(env.channelUpdater!.startWatching_cid, channelId)
        XCTAssertFalse(completionCalled)
        
        // Simulate successful update
        env.channelUpdater!.startWatching_completion?(nil)
        // Release reference of completion so we can deallocate stuff
        env.channelUpdater!.startWatching_completion = nil
        
        AssertAsync {
            // Assert completion is called
            Assert.willBeTrue(completionCalled)
            // `weakController` should be deallocated too
            Assert.canBeReleased(&weakController)
        }
    }
    
    func test_startWatching_propagatesErrorFromUpdater() {
        // Simulate `startWatching` call and catch the completion
        var completionCalledError: Error?
        controller.startWatching(isInRecoveryMode: false) { [callbackQueueID] in
            AssertTestQueue(withId: callbackQueueID)
            completionCalledError = $0
        }
        
        // Simulate failed update
        let testError = TestError()
        env.channelUpdater!.startWatching_completion?(testError)
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
    }

    func test_watchActiveChannelWithoutCidAlreadyCreated() {
        let editPayload = ChannelEditDetailPayload(
            type: .messaging,
            name: nil,
            imageURL: nil,
            team: nil,
            members: Set(),
            invites: Set(),
            extraData: [:]
        )

        let receivedError = watchActiveChannelAndWait(
            channelQuery: ChannelQuery(channelPayload: editPayload),
            isChannelAlreadyCreated: true,
            requestBlock: { channelUpdater in
                channelUpdater?.update_completion?(.success(dummyPayload(with: .unique)))
            }
        )

        XCTAssertNil(receivedError)
        XCTAssertNil(env.channelUpdater?.startWatching_cid)
        XCTAssertEqual(env.channelUpdater?.update_callCount, 1)
    }

    func test_watchActiveChannelWithCidNotAlreadyCreated() {
        let receivedError = watchActiveChannelAndWait(isChannelAlreadyCreated: false, requestBlock: { channelUpdater in
            channelUpdater?.update_completion?(.success(dummyPayload(with: .unique)))
        })

        XCTAssertNil(receivedError)
        XCTAssertNil(env.channelUpdater?.startWatching_cid)
        XCTAssertEqual(env.channelUpdater?.update_callCount, 1)
    }

    func test_watchActiveChannelWithCidAlreadyCreated() {
        let receivedError = watchActiveChannelAndWait(isChannelAlreadyCreated: true, requestBlock: { channelUpdater in
            channelUpdater?.startWatching_completion?(nil)
        })

        XCTAssertNil(receivedError)
        XCTAssertEqual(env.channelUpdater?.startWatching_cid, channelId)
        XCTAssertEqual(env.channelUpdater?.update_callCount, 0)
    }

    private func watchActiveChannelAndWait(
        channelQuery: ChannelQuery? = nil,
        isChannelAlreadyCreated: Bool,
        requestBlock: (ChannelUpdater_Mock?) -> Void
    ) -> Error? {
        controller = ChatChannelController(
            channelQuery: channelQuery ?? .init(cid: channelId),
            channelListQuery: nil,
            client: client,
            environment: env.environment,
            isChannelAlreadyCreated: isChannelAlreadyCreated
        )

        env.channelUpdater?.cleanUp()

        var receivedError: Error?
        let expectation = self.expectation(description: "watchActiveChannel completion")
        controller.recoverWatchedChannel { error in
            receivedError = error
            expectation.fulfill()
        }

        requestBlock(env.channelUpdater)

        waitForExpectations(timeout: 0.5, handler: nil)
        return receivedError
    }
    
    // MARK: - Stop watching
    
    func test_stopWatching_failsForNewChannels() throws {
        //  Create `ChannelController` for new channel
        let query = ChannelQuery(channelPayload: .unique)
        setupControllerForNewChannel(query: query)
        
        // Simulate `stopWatching` call and assert error is returned
        var error: Error? = try waitFor { [callbackQueueID] completion in
            controller.stopWatching { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
        }
        XCTAssert(error is ClientError.ChannelNotCreatedYet)
        
        // Simulate successful backend channel creation
        env.channelUpdater!.update_channelCreatedCallback?(query.cid!)
        
        // Simulate `stopWatching` call and assert no error is returned
        error = try waitFor { [callbackQueueID] completion in
            controller.stopWatching { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
            env.channelUpdater!.stopWatching_completion?(nil)
        }
        
        XCTAssertNil(error)
    }
    
    func test_stopWatching_callsChannelUpdater() {
        // Simulate `stopWatching` call and catch the completion
        var completionCalled = false
        controller.stopWatching { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            completionCalled = true
        }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Assert cid is passed to `channelUpdater`, completion is not called yet
        XCTAssertEqual(env.channelUpdater!.stopWatching_cid, channelId)
        XCTAssertFalse(completionCalled)
        
        // Simulate successful update
        env.channelUpdater!.stopWatching_completion?(nil)
        // Release reference of completion so we can deallocate stuff
        env.channelUpdater!.stopWatching_completion = nil
        
        AssertAsync {
            // Assert completion is called
            Assert.willBeTrue(completionCalled)
            // `weakController` should be deallocated too
            Assert.canBeReleased(&weakController)
        }
    }
    
    func test_stopWatching_propagatesErrorFromUpdater() {
        // Simulate `stopWatching` call and catch the completion
        var completionCalledError: Error?
        controller.stopWatching { [callbackQueueID] in
            AssertTestQueue(withId: callbackQueueID)
            completionCalledError = $0
        }
        
        // Simulate failed update
        let testError = TestError()
        env.channelUpdater!.stopWatching_completion?(testError)
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
    }
    
    // MARK: - Freeze channel
    
    func test_freezeChannel_failsForNewChannels() throws {
        //  Create `ChannelController` for new channel
        let query = ChannelQuery(channelPayload: .unique)
        setupControllerForNewChannel(query: query)
        
        // Simulate `freezeChannel` call and assert error is returned
        var error: Error? = try waitFor { [callbackQueueID] completion in
            controller.freezeChannel { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
        }
        XCTAssert(error is ClientError.ChannelNotCreatedYet)
        
        // Simulate successful backend channel creation
        env.channelUpdater!.update_channelCreatedCallback?(query.cid!)
        
        // Simulate `freezeChannel` call and assert no error is returned
        error = try waitFor { [callbackQueueID] completion in
            controller.freezeChannel { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
            env.channelUpdater!.freezeChannel_completion?(nil)
        }
        
        XCTAssertNil(error)
    }
    
    func test_freezeChannel_callsChannelUpdater() {
        // Simulate `freezeChannel` call and catch the completion
        var completionCalled = false
        controller.freezeChannel { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            completionCalled = true
        }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Assert cid is passed to `channelUpdater`, completion is not called yet
        XCTAssertEqual(env.channelUpdater!.freezeChannel_cid, channelId)
        XCTAssertFalse(completionCalled)
        
        // Assert that `frozen: true` is passed as payload
        XCTAssertEqual(env.channelUpdater!.freezeChannel_freeze, true)
        
        // Simulate successful update
        env.channelUpdater!.freezeChannel_completion?(nil)
        // Release reference of completion so we can deallocate stuff
        env.channelUpdater!.freezeChannel_completion = nil
        
        AssertAsync {
            // Assert completion is called
            Assert.willBeTrue(completionCalled)
            // `weakController` should be deallocated too
            Assert.canBeReleased(&weakController)
        }
    }
    
    func test_freezeChannel_propagatesErrorFromUpdater() {
        // Simulate `freezeChannel` call and catch the completion
        var completionCalledError: Error?
        controller.freezeChannel { [callbackQueueID] in
            AssertTestQueue(withId: callbackQueueID)
            completionCalledError = $0
        }
        
        // Simulate failed update
        let testError = TestError()
        env.channelUpdater!.freezeChannel_completion?(testError)
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
    }
    
    // MARK: - Unfreeze channel
    
    func test_unfreezeChannel_failsForNewChannels() throws {
        //  Create `ChannelController` for new channel
        let query = ChannelQuery(channelPayload: .unique)
        setupControllerForNewChannel(query: query)
        
        // Simulate `unfreezeChannel` call and assert error is returned
        var error: Error? = try waitFor { [callbackQueueID] completion in
            controller.unfreezeChannel { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
        }
        XCTAssert(error is ClientError.ChannelNotCreatedYet)
        
        // Simulate successful backend channel creation
        env.channelUpdater!.update_channelCreatedCallback?(query.cid!)
        
        // Simulate `unfreezeChannel` call and assert no error is returned
        error = try waitFor { [callbackQueueID] completion in
            controller.unfreezeChannel { error in
                AssertTestQueue(withId: callbackQueueID)
                completion(error)
            }
            env.channelUpdater!.freezeChannel_completion?(nil)
        }
        
        XCTAssertNil(error)
    }
    
    func test_unfreezeChannel_callsChannelUpdater() {
        // Simulate `unfreezeChannel` call and catch the completion
        var completionCalled = false
        controller.unfreezeChannel { [callbackQueueID] error in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(error)
            completionCalled = true
        }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Assert cid is passed to `channelUpdater`, completion is not called yet
        XCTAssertEqual(env.channelUpdater!.freezeChannel_cid, channelId)
        XCTAssertFalse(completionCalled)
        
        // Assert that `frozen: false` is passed as payload
        XCTAssertEqual(env.channelUpdater!.freezeChannel_freeze, false)
        
        // Simulate successful update
        env.channelUpdater!.freezeChannel_completion?(nil)
        // Release reference of completion so we can deallocate stuff
        env.channelUpdater!.freezeChannel_completion = nil
        
        AssertAsync {
            // Assert completion is called
            Assert.willBeTrue(completionCalled)
            // `weakController` should be deallocated too
            Assert.canBeReleased(&weakController)
        }
    }
    
    func test_unfreezeChannel_propagatesErrorFromUpdater() {
        // Simulate `freezeChannel` call and catch the completion
        var completionCalledError: Error?
        controller.unfreezeChannel { [callbackQueueID] in
            AssertTestQueue(withId: callbackQueueID)
            completionCalledError = $0
        }
        
        // Simulate failed update
        let testError = TestError()
        env.channelUpdater!.freezeChannel_completion?(testError)
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
    }
    
    // MARK: - UploadFile
    
    func test_uploadFile_failsForNewChannels() throws {
        //  Create `ChannelController` for new channel
        let query = ChannelQuery(channelPayload: .unique)
        setupControllerForNewChannel(query: query)
        
        // Simulate `uploadFile` call and assert error is returned
        var error: Error? = try waitFor { [callbackQueueID] completion in
            controller.uploadFile(localFileURL: .localYodaImage) { result in
                AssertTestQueue(withId: callbackQueueID)
                completion(result.error)
            }
        }
        XCTAssert(error is ClientError.ChannelNotCreatedYet)
        
        // Simulate successful backend channel creation
        env.channelUpdater!.update_channelCreatedCallback?(query.cid!)
        
        // Simulate `uploadFile` call and assert no error is returned
        error = try waitFor { [callbackQueueID] completion in
            controller.uploadFile(localFileURL: .localYodaImage) { result in
                AssertTestQueue(withId: callbackQueueID)
                completion(result.error)
            }
            env.channelUpdater!.uploadFile_completion?(.success(.localYodaQuote))
        }
        
        XCTAssertNil(error)
    }
    
    func test_uploadFile_callsChannelUpdater() {
        // Simulate `uploadFile` call and catch the completion
        var completionCalled = false
        controller.uploadFile(localFileURL: .localYodaImage) { [callbackQueueID] result in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(result.error)
            completionCalled = true
        }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Assert cid is passed to `channelUpdater`, completion is not called yet
        XCTAssertEqual(env.channelUpdater!.uploadFile_cid, channelId)
        // Assert correct type is passed
        XCTAssertEqual(env.channelUpdater?.uploadFile_type, .file)
        XCTAssertFalse(completionCalled)
        
        // Simulate successful update
        env.channelUpdater!.uploadFile_completion?(.success(.localYodaQuote))
        // Release reference of completion so we can deallocate stuff
        env.channelUpdater!.uploadFile_completion = nil
        
        AssertAsync {
            // Assert completion is called
            Assert.willBeTrue(completionCalled)
            // `weakController` should be deallocated too
            Assert.canBeReleased(&weakController)
        }
    }
    
    func test_uploadFile_propagatesErrorFromUpdater() {
        // Simulate `uploadFile` call and catch the completion
        var completionCalledError: Error?
        controller.uploadFile(localFileURL: .localYodaImage) { [callbackQueueID] in
            AssertTestQueue(withId: callbackQueueID)
            completionCalledError = $0.error
        }
        
        // Simulate failed update
        let testError = TestError()
        env.channelUpdater!.uploadFile_completion?(.failure(testError))
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
    }
    
    // MARK: - UploadImage
    
    func test_uploadImage_failsForNewChannels() throws {
        //  Create `ChannelController` for new channel
        let query = ChannelQuery(channelPayload: .unique)
        setupControllerForNewChannel(query: query)
        
        // Simulate `uploadImage` call and assert error is returned
        var error: Error? = try waitFor { [callbackQueueID] completion in
            controller.uploadImage(localFileURL: .localYodaImage) { result in
                AssertTestQueue(withId: callbackQueueID)
                completion(result.error)
            }
        }
        XCTAssert(error is ClientError.ChannelNotCreatedYet)
        
        // Simulate successful backend channel creation
        env.channelUpdater!.update_channelCreatedCallback?(query.cid!)
        
        // Simulate `uploadImage` call and assert no error is returned
        error = try waitFor { [callbackQueueID] completion in
            controller.uploadImage(localFileURL: .localYodaImage) { result in
                AssertTestQueue(withId: callbackQueueID)
                completion(result.error)
            }
            env.channelUpdater!.uploadFile_completion?(.success(.localYodaQuote))
        }
        
        XCTAssertNil(error)
    }
    
    func test_uploadImage_callsChannelUpdater() {
        // Simulate `uploadImage` call and catch the completion
        var completionCalled = false
        controller.uploadImage(localFileURL: .localYodaImage) { [callbackQueueID] result in
            AssertTestQueue(withId: callbackQueueID)
            XCTAssertNil(result.error)
            completionCalled = true
        }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Assert cid is passed to `channelUpdater`, completion is not called yet
        XCTAssertEqual(env.channelUpdater!.uploadFile_cid, channelId)
        // Assert correct type is passed
        XCTAssertEqual(env.channelUpdater?.uploadFile_type, .image)
        XCTAssertFalse(completionCalled)
        
        // Simulate successful update
        env.channelUpdater!.uploadFile_completion?(.success(.localYodaQuote))
        // Release reference of completion so we can deallocate stuff
        env.channelUpdater!.uploadFile_completion = nil
        
        AssertAsync {
            // Assert completion is called
            Assert.willBeTrue(completionCalled)
            // `weakController` should be deallocated too
            Assert.canBeReleased(&weakController)
        }
    }
    
    func test_uploadImage_propagatesErrorFromUpdater() {
        // Simulate `uploadImage` call and catch the completion
        var completionCalledError: Error?
        controller.uploadImage(localFileURL: .localYodaImage) { [callbackQueueID] in
            AssertTestQueue(withId: callbackQueueID)
            completionCalledError = $0.error
        }
        
        // Simulate failed update
        let testError = TestError()
        env.channelUpdater!.uploadFile_completion?(.failure(testError))
        
        // Completion should be called with the error
        AssertAsync.willBeEqual(completionCalledError as? TestError, testError)
    }
    
    // MARK: - Load pinned messages
    
    func test_loadPinnedMessages_failsForNewChannel() throws {
        //  Create `ChannelController` for new channel
        let query = ChannelQuery(channelPayload: .unique)
        setupControllerForNewChannel(query: query)
        
        // Simulate `loadPinnedMessages` call and assert error is returned
        let error: Error? = try waitFor { [callbackQueueID] completion in
            controller.loadPinnedMessages { result in
                AssertTestQueue(withId: callbackQueueID)
                completion(result.error)
            }
        }
        
        // Assert `ClientError.ChannelNotCreatedYet` is propagated to completion
        XCTAssert(error is ClientError.ChannelNotCreatedYet)
    }
    
    func test_loadPinnedMessages_callsChannelUpdater() {
        let pageSize = 10
        let pagination = PinnedMessagesPagination.aroundMessage(.unique)
        
        // Simulate `loadPinnedMessages` call
        controller.loadPinnedMessages(pageSize: pageSize, pagination: pagination) { _ in }
        
        // Assert call is propagated to updater
        XCTAssertEqual(env.channelUpdater!.loadPinnedMessages_cid, controller.cid)
        XCTAssertEqual(env.channelUpdater!.loadPinnedMessages_query, .init(pageSize: pageSize, pagination: pagination))
    }
    
    func test_loadPinnedMessages_propagatesErrorFromUpdater() {
        // Simulate `loadPinnedMessages` call and catch the completion
        var completionError: Error?
        controller.loadPinnedMessages { [callbackQueueID] in
            AssertTestQueue(withId: callbackQueueID)
            completionError = $0.error
        }
        
        // Simulate failed update
        let testError = TestError()
        env.channelUpdater!.loadPinnedMessages_completion!(.failure(testError))
        
        // Error is propagated to completion
        AssertAsync.willBeEqual(completionError as? TestError, testError)
    }
    
    func test_loadPinnedMessages_keepsControllerAlive() {
        // Simulate `loadPinnedMessages` call
        controller.loadPinnedMessages { _ in }
        
        // Keep a weak ref so we can check if it's actually deallocated
        weak var weakController = controller
        
        // (Try to) deallocate the controller
        // by not keeping any references to it
        controller = nil
        
        // Assert controller is kept alive
        AssertAsync.staysTrue(weakController != nil)
    }

    // MARK: Init registers active controller

    func test_initRegistersActiveController() {
        let client = ChatClient.mock
        let channelQuery = ChannelQuery(cid: channelId)
        let channelListQuery = ChannelListQuery(filter: .containMembers(userIds: [.unique]))

        let controller = ChatChannelController(
            channelQuery: channelQuery,
            channelListQuery: channelListQuery,
            client: client
        )

        XCTAssert(controller.client === client)
        XCTAssert(client.activeChannelControllers.count == 1)
        XCTAssert(client.activeChannelControllers.allObjects.first === controller)
    }
}

// MARK: Test Helpers

extension ChannelController_Tests {
    // MARK: - Helpers

    func setupControllerForNewDirectMessageChannel(
        currentUserId: UserId,
        otherUserId: UserId,
        channelListQuery: ChannelListQuery? = nil
    ) {
        let payload = ChannelEditDetailPayload(
            type: .messaging,
            name: nil,
            imageURL: nil,
            team: nil,
            members: [currentUserId, otherUserId],
            invites: [],
            extraData: [:]
        )

        controller = ChatChannelController(
            channelQuery: .init(channelPayload: payload),
            channelListQuery: channelListQuery,
            client: client,
            environment: env.environment,
            isChannelAlreadyCreated: false
        )
        controller.callbackQueue = .testQueue(withId: controllerCallbackQueueID)
    }

    func setupControllerForNewChannel(
        query: ChannelQuery,
        channelListQuery: ChannelListQuery? = nil
    ) {
        controller = ChatChannelController(
            channelQuery: query,
            channelListQuery: channelListQuery,
            client: client,
            environment: env.environment,
            isChannelAlreadyCreated: false
        )
        controller.callbackQueue = .testQueue(withId: controllerCallbackQueueID)
        controller.synchronize()
    }

    func setupControllerForNewMessageChannel(
        cid: ChannelId,
        channelListQuery: ChannelListQuery? = nil
    ) {
        let payload = ChannelEditDetailPayload(
            cid: cid,
            name: nil,
            imageURL: nil,
            team: nil,
            members: [],
            invites: [],
            extraData: [:]
        )

        controller = ChatChannelController(
            channelQuery: .init(channelPayload: payload),
            channelListQuery: channelListQuery,
            client: client,
            environment: env.environment,
            isChannelAlreadyCreated: false
        )
        controller.callbackQueue = .testQueue(withId: controllerCallbackQueueID)
    }

    // Helper function that creates channel with message
    func setupChannelWithMessage(_ session: DatabaseSession) throws -> MessageId {
        let dummyUserPayload: CurrentUserPayload = .dummy(userId: .unique, role: .user)
        try session.saveCurrentUser(payload: dummyUserPayload)
        try session.saveChannel(payload: dummyPayload(with: channelId))
        let message = try session.createNewMessage(
            in: channelId,
            text: "Message",
            pinning: nil,
            quotedMessageId: nil,
            isSilent: false,
            attachments: [
                .mockImage,
                .mockFile,
                .init(payload: TestAttachmentPayload.unique)
            ],
            extraData: [:]
        )
        return message.id
    }
}

private class TestEnvironment {
    var channelUpdater: ChannelUpdater_Mock?
    var eventSender: TypingEventsSender_Mock?

    lazy var environment: ChatChannelController.Environment = .init(
        channelUpdaterBuilder: { [unowned self] in
            self.channelUpdater = ChannelUpdater_Mock(database: $0, apiClient: $1)
            return self.channelUpdater!
        },
        eventSenderBuilder: { [unowned self] in
            self.eventSender = TypingEventsSender_Mock(database: $0, apiClient: $1)
            return self.eventSender!
        }
    )
}
